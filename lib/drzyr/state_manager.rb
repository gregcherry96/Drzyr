# lib/drzyr/state_manager.rb

# frozen_string_literal: true

module Drzyr
  class StateManager
    attr_reader :connections, :pages, :state, :pending_button_presses, :lock,
                :before_filters, :after_filters

    def initialize
      @connections = {}
      @pages = Hash.new { |h, k| h[k] = {} }
      @state = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }
      @pending_button_presses = Hash.new { |h, k| h[k] = {} }
      @lock = Mutex.new
      @before_filters = []
      @after_filters = []
    end

    def synchronized(&block)
      @lock.synchronize(&block)
    end

    def add_before_filter(pattern, block)
      # Convert the path pattern string into a Regexp for matching
      @before_filters << { pattern: Regexp.new(pattern.gsub('*', '.*?')), block: block }
    end

    def add_after_filter(pattern, block)
      @after_filters << { pattern: Regexp.new(pattern.gsub('*', '.*?')), block: block }
    end
  end
end
