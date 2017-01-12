require 'routemaster'
require 'routemaster/mixins/log'
require 'singleton'

module Routemaster
  class Configuration
    include Singleton
    include Mixins::Log

    DEFAULTS = {
      redis_pool_size: 1,
      process_type:    'unknown',
    }.freeze

    def configure(**options)
      @_config = DEFAULTS.merge(options)
      _new_relic_setup
      _counters.incr('process', type: config[:process_type], status: 'start')
    end

    def teardown
      _counters.incr('process', type: config[:process_type], status: 'stop').finalize
      _new_relic_teardown
    end

    def config
      @_config || DEFAULTS
    end

    private

    def _counters
      @_counters ||= begin
        require 'routemaster/models/counters'
        Models::Counters.instance
      end
    end

    def _new_relic_setup
      return unless ENV['NEW_RELIC_LICENSE_KEY']
      _log.info { 'setting up New Relic' }
      # load Redis first so that New relic instruments it
      require 'redis'
      require 'newrelic_rpm'
      GC::Profiler.enable

      # report jobs runs as transactions
      require 'routemaster/models/job'
      Routemaster::Models::Job.class_eval do
        include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation

        alias_method :perform_without_transaction_rename, :perform
        def perform
          NewRelic::Agent.set_transaction_name("#{self.class.name}/#{@name}")
          perform_without_transaction_rename
        end

        add_transaction_tracer :perform, :category => :task
      end
    end

    def _new_relic_teardown
      return unless ENV['NEW_RELIC_LICENSE_KEY']
      _log.info { 'shutting down New Relic' }
      # force the agent to finish working - particularly, report errors
      ::NewRelic::Agent.shutdown
    end
  end
end
