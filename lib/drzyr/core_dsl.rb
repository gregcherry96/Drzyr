# frozen_string_literal: true

# lib/drzyr/core_dsl.rb
def get(path, &block)
  Drzyr.register_page(path, :get, &block)
end

def post(path, &block)
  Drzyr.register_page(path, :post, &block)
end

def react(path, &block)
  Drzyr.register_page(path, :react, &block)
end
