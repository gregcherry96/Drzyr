# lib/drzyr/core_dsl.rb

# frozen_string_literal: true

# Add the custom `react` method directly to the Sinatra Base class,
# making it available in all your route files.
class Sinatra::Base
  def react(path, &block)
    get(path, &block)
  end
end
