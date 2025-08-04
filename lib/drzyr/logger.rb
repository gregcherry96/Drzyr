# frozen_string_literal: true

# lib/drzyr/logger.rb
module Drzyr
  class Logger
    def self.info(message)
      puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] \e[32mINFO\e[0m  #{message}"
    end
  end

  class RequestLogger
    def initialize(app)
      @app = app
    end

    def call(env)
      start_time = Time.now
      status, headers, body = @app.call(env)
      end_time = Time.now

      unless env['PATH_INFO'].start_with?('/main.css', '/javascript.js', '/websocket')
        Logger.info "#{env['REQUEST_METHOD']} #{env['PATH_INFO']} - \e[36m#{status}\e[0m in #{((end_time - start_time) * 1000).round(2)}ms"
      end

      [status, headers, body]
    end
  end
end
