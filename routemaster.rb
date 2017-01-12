require 'routemaster/configuration'
require 'delegate'

module Routemaster
  def self.now
    (Time.now.utc.to_f * 1e3).to_i
  end

  extend SingleForwardable
  delegate %i[configure teardown config] => '::Routemaster::Configuration.instance'

  def self.batch_queue
    @_batch_queue ||= begin
      require 'routemaster/models/queue'
      Models::Queue.new(name: 'main')
    end
  end

  def self.aux_queue
    @_aux_queue ||= begin
      require 'routemaster/models/queue'
      Models::Queue.new(name: 'aux')
    end
  end

  def self.counters
    @_counters ||= begin
      require 'routemaster/models/counters'
      Models::Counters.instance
    end
  end
end
