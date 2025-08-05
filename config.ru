# frozen_string_literal: true

# config.ru
require 'roda'
require_relative './app'

run Drzyr::Server.freeze.app
