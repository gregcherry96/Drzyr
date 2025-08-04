# config.ru

# frozen_string_literal: true

# Now require your application code
require_relative './app'

# Falcon will automatically use this file.
run Drzyr::Server.freeze.app
