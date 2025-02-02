# https://github.com/zombocom/rack-timeout/blob/main/doc/logging.md
# state changes into timed_out and expired are logged at the ERROR level

# Log ready and completed messages in DEBUG mode only (instead of default INFO)
Rack::Timeout::StateChangeLoggingObserver::STATE_LOG_LEVEL[:ready] = :debug
Rack::Timeout::StateChangeLoggingObserver::STATE_LOG_LEVEL[:completed] = :debug

# Custom format for logs
class RackTimeoutFormatter < ::Logger::Formatter
  include ActiveSupport::LoggerSilence

  def call(severity, timestamp, progname, msg)
    # TOFIX: find env info (or extract it from msg param).
    # It's mentioned here but I must be doing it wrong: https://github.com/zombocom/rack-timeout/blob/main/doc/logging.md
    info = env['rack-timeout.info']

    # TODO: include severity, timestamp
    "[#{info.delete(:info)}] #{info.delete(:source)}: #{info.delete(:state)} -- #{info}"
  end
end

Rack::Timeout::Logger.logger = Logger.new(STDERR, formatter: RackTimeoutFormatter.new)
