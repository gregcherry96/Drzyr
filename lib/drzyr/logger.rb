# frozen_string_literal: true

require 'logger'

module Drzyr
  # A centralized, configurable logger for the Drzyr framework.
  class Logger
    # Color codes for log levels
    COLORS = {
      'INFO' => '32', # Green
      'WARN' => '33', # Yellow
      'ERROR' => '31', # Red
      'FATAL' => '35', # Magenta
      'DEBUG' => '36' # Cyan
    }.freeze

    def self.new_logger(output = $stdout)
      logger = ::Logger.new(output)
      logger.level = ::Logger::INFO # Default log level
      logger.formatter = proc do |severity, datetime, _progname, msg|
        color = COLORS[severity] || '0'
        formatted_time = datetime.strftime('%Y-%m-%d %H:%M:%S')
        "\e[#{color}m[#{formatted_time}] #{severity.ljust(5)}: #{msg}\e[0m\n"
      end
      logger
    end

    def self.logger
      @logger ||= new_logger
    end

    def self.info(message)
      logger.info(message)
    end

    def self.warn(message)
      logger.warn(message)
    end

    def self.error(message)
      logger.error(message)
    end

    def self.debug(message)
      logger.debug(message)
    end
  end

  # Rack middleware for logging HTTP requests.
  class RequestLogger
    EXCLUDED_PATHS = ['/main.css', '/javascript.js', '/websocket'].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      start_time = Time.now
      status, headers, body = @app.call(env)
      log_request(env, status, start_time)
      [status, headers, body]
    end

    private

    def log_request(env, status, start_time)
      path = env['PATH_INFO']
      return if EXCLUDED_PATHS.any? { |p| path.start_with?(p) }

      duration = ((Time.now - start_time) * 1000).round(2)
      method = env['REQUEST_METHOD']
      status_color = status >= 500 ? '31' : '32' # Red for server errors, green otherwise

      Logger.info "#{method} #{path} - \e[#{status_color}m#{status}\e[0m in #{duration}ms"
    end
  end
end
