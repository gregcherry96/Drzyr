# config.ru

# frozen_string_literal: true

require 'bundler/setup'
Bundler.require(:default)

# Load the entire Drzyr framework from the single file.
require_relative './lib/drzyr'

# Load all route files, which will add routes to the Drzyr::App class.
require_relative './app'
Dir['./routes/**/*.rb'].each { |file|
require_relative file }

# Run the application using the correct class name.
run Drzyr::App
