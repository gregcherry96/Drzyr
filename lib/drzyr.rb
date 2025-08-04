# lib/drzyr.rb
# frozen_string_literal: true

# External gems
require 'roda'
require 'json'
require 'erb'
require 'securerandom'
require 'date'

# Drzyr components
require_relative 'drzyr/version'
require_relative 'drzyr/logger'
require_relative 'drzyr/state_manager'
require_relative 'drzyr/html_renderer'
require_relative 'drzyr/builders/column_builder'
require_relative 'drzyr/builders/navbar_builder'
require_relative 'drzyr/builders/tab_builder'
require_relative 'drzyr/builders/ui_builder'
require_relative 'drzyr/server'
require_relative 'drzyr/core_dsl'
