# frozen_string_literal: true

# lib/drzyr/state_manager.rb
module Drzyr
  class StateManager
    attr_reader :connections, :pages, :state, :pending_button_presses, :lock

    def initialize
      @connections = {}
      @pages = {}
      @state = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }
      @pending_button_presses = Hash.new { |h, k| h[k] = {} }
      @lock = Mutex.new
    end

    def synchronized(&block)
      @lock.synchronize(&block)
    end
  end
end
