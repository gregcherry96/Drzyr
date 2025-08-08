# frozen_string_literal: true

# lib/drzyr/state_manager.rb
module Drzyr
  # Manages all server-side state for the Drzyr framework. This includes
  # tracking active WebSocket connections, page definitions, and the state
  # for each user session. It also handles the locking mechanisms required for
  # concurrent access to shared data.
  class StateManager
    attr_reader :connections, :pages, :state, :pending_button_presses, :lock

    def initialize
      # This lock protects the top-level hashes (connections, state hash itself, etc.)
      @lock = Mutex.new
      @connections = {}
      @pages = {}
      # The state hash holds a dedicated lock and data hash for each session.
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
