require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/webmock'
require 'core_ext/math'

# turn this on to get verbose tests
VERBOSE = ENV.fetch('VERBOSE_ACCEPTANCE_TESTS', 'NO') == 'YES'

module Acceptance
  class SubProcess
    def initialize(name:, command:, start: nil, stop: nil)
      @name    = name
      @command = command
      @pid     = nil
      @reader  = nil
      @loglines = []
      @full_logs = []
      @start_regexp = start
      @stop_regexp  = stop
    end

    def start
      raise 'already started' if @pid
      _log 'starting'
      @loglines = []
      @full_logs = []
      rd_o, wr_o = IO.pipe
      rd_e, wr_e = IO.pipe
      if @pid = fork
        # parent
        wr_o.close
        wr_e.close
        @reader = Thread.new { _read_log(rd_o, rd_e) }
      else
        _log "forked (##{$$})"
        # child
        rd_o.close
        rd_e.close
        ENV['ROUTEMASTER_LOG_FILE'] = nil
        $stdin.reopen('/dev/null')
        $stdout.reopen(wr_o)
        $stderr.reopen(wr_e)
        $stdout.sync = true
        $stderr.sync = true
        exec @command
      end
      self
    end

    # politely ask the process to stop
    def stop
      return if @pid.nil?
      _log "stopping (##{@pid})"
      Process.kill('TERM', @pid)
      self
    end

    # after calling `start`, wait until the process has logged a line indicating
    # it is ready for use
    def wait_start
      return unless @start_regexp && @pid
      _log 'waiting to start'
      wait_log @start_regexp
      _log "started (##{@pid})"
      self
    end

    # after calling `stop`, wait until the log exhibits an entry indicating
    # the process has stoped cleanly
    def wait_stop
      return unless @stop_regexp && @pid
      _log "waiting to stop (##{@pid})"
      sleep 0.5 # give the process time to "properly" start, set up signals etc
      wait_log @stop_regexp
      _log 'stopped'
    ensure
      terminate
    end

    # terminate the process without waiting
    def terminate
      if @pid
        _log "terminating (##{@pid})"
        Process.kill('KILL', @pid)
        Process.wait(@pid)
      end
      @reader.join if @reader
      @pid = @reader = nil
      self
    end

    # wait until a log line is seen that matches `regexp`, up to a timeout
    def wait_log(regexp)
      Timeout::timeout(10) do
        loop do
          line = @loglines.shift
          sleep(10.ms) if line.nil?
          break if line && line =~ regexp
        end
      end
      self
    end

    def dump_logs(io: STDERR)
      @full_logs.each { |line| io.write line }
    end

    private

    def _read_log(*ios)
      loop do
        IO.select(ios).first.each do |io|
          line = io.gets
          if line.nil?
            ios.delete(io)
            next
          end

          if VERBOSE
            $stderr.write line
            $stderr.flush
          else
            @full_logs.push line
          end
          @loglines.push line
        end
        break if ios.empty?
      end
    end

    def _log(message)
      line = "\t-> #{@name}: #{message}\n"
      if VERBOSE
        $stderr.write line
      else
        @full_logs.push line
      end
    end
  end

  class ProcessLibrary
    def watch
      @watch ||= SubProcess.new(
        name:    'worker',
        command: './bin/worker',
        start:   /job worker: started/,
        stop:    /job worker: completed/
      )
    end

    def web
      @web ||= SubProcess.new(
        name:    'web',
        command: 'puma -I. -C config/puma.rb',
        start:   /Worker 1.*booted/,
        stop:    /Puma master exiting/
      )
    end

    def client
      @client ||= SubProcess.new(
        name:    'client',
        command: 'puma -I. -w 2 -p 17892 -C spec/support/client-puma.rb spec/support/client.ru',
        start:   /Worker 1.*booted/,
        stop:    /Puma master exiting/
      )
    end

    def server_tunnel
      @server_tunnel ||= SubProcess.new(
        name:    'server-tunnel',
        command: 'ruby spec/support/tunnel 127.0.0.1:17893 127.0.0.1:17891',
        start:   /Ready/,
        stop:    /tunnel terminated/,
      )
    end

    def client_tunnel 
      @client_tunnel ||= SubProcess.new(
        name:    'client-tunnel',
        command: 'ruby spec/support/tunnel 127.0.0.1:17894 127.0.0.1:17892',
        start:   /Ready/,
        stop:    /tunnel terminated/,
      )
    end

    def all
      [server_tunnel, client_tunnel, watch, web, client]
    end
  end
end

