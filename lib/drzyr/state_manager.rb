# frozen_string_literal: true

# lib/drzyr/state_manager.rb
module Drzyr
  class StateManager
    attr_reader :connections, :pages, :state, :pending_button_presses, :lock

    def initialize
      # This lock protects the top-level hashes (connections, state hash itself, etc.)
      @lock = Mutex.new
      @connections = {}
      @pages = {}
      # The state hash now holds a dedicated lock and data hash for each session.
      @state = Hash.new do |h, session_id|
        h[session_id] = {
          lock: Mutex.new,
          data: Hash.new { |h2, path| h2[path] = {} }
        }
      end
      @pending_button_presses = Hash.new { |h, ws| h[ws] = {} }
    end

    # Synchronizes access to the top-level collections.
    def synchronized(&block)
      @lock.synchronize(&block)
    end
  end
end
