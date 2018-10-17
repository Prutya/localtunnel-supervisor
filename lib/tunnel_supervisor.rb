# frozen_string_literal: true

require 'yaml'
require 'logger'

class TunnelSupervisor
  attr_reader :log

  MONITOR_SLEEP_DEFAULT = 1

  def initialize(config, log:, monitor_sleep: MONITOR_SLEEP_DEFAULT)
    @config = config
    @pids = {}
    @log = log
    @monitor_sleep = monitor_sleep
  end

  def start!
    @config.each { |key, conf| start_one(key, conf) }

    self
  end

  def monitor!
    loop do
      @pids.each do |key, pid|
        @log.debug("Checking #{key}[PID:#{pid}]")

        Process.getpgid(pid)

        @log.debug("#{key}[PID]:#{pid} is alive.")
      rescue Errno::ESRCH
        @log.warn("#{key}[PID:#{pid}] has crashed. Restarting.")

        start_one(key, @config[key])
      end

      sleep @monitor_sleep
    end

    self
  end

  private

  def start_one(key, conf)
    @log.info("Starting #{key} tunnel...")

    command = create_command(port: conf['port'], subdomain: conf['subdomain'])
    @pids[key] = Process.fork { `#{command}` }

    @log.info [
      'Done.',
      "PID: #{@pids[key]}",
      "Domain: #{conf['subdomain']}.localtunnel.me",
      "Port: #{conf['port']}"
    ].join(' ')
  end

  def create_command(port:, subdomain:)
    <<~SHELL
      lt --port #{port} --subdomain #{subdomain}
    SHELL
  end
end