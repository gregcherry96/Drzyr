# lib/drzyr/core_dsl.rb

# frozen_string_literal: true

# A helper to centralize route registration
def drzyr_register_page(path, type, &block)
  Drzyr.state.pages[path] ||= {}
  Drzyr.state.pages[path][type.to_s.upcase] = { type: type, block: block }
end

# --- Core Verbs ---

def get(path, &block)
  drzyr_register_page(path, :get, &block)
end

def post(path, &block)
  drzyr_register_page(path, :post, &block)
end

def react(path, &block)
  drzyr_register_page(path, :react, &block)
end

def put(path, &block)
  drzyr_register_page(path, :put, &block)
end

def patch(path, &block)
  drzyr_register_page(path, :patch, &block)
end

def delete(path, &block)
  drzyr_register_page(path, :delete, &block)
end

# --- Namespace and Filters DSL ---

module Drzyr
  module Dsl
    class Namespace
      def initialize(prefix)
        @prefix = prefix
      end

      def get(path, &block)
        drzyr_register_page("#{@prefix}#{path}", :get, &block)
      end

      def post(path, &block)
        drzyr_register_page("#{@prefix}#{path}", :post, &block)
      end

      def put(path, &block)
        drzyr_register_page("#{@prefix}#{path}", :put, &block)
      end

      def patch(path, &block)
        drzyr_register_page("#{@prefix}#{path}", :patch, &block)
      end

      def delete(path, &block)
        drzyr_register_page("#{@prefix}#{path}", :delete, &block)
      end

      def react(path, &block)
        drzyr_register_page("#{@prefix}#{path}", :react, &block)
      end
    end

    def namespace(prefix, &block)
      namespace_dsl = Namespace.new(prefix)
      namespace_dsl.instance_eval(&block)
    end

    def before(path_pattern = '*', &block)
      Drzyr.state.add_before_filter(path_pattern, block)
    end

    def after(path_pattern = '*', &block)
      Drzyr.state.add_after_filter(path_pattern, block)
    end
  end
end

# Make all DSL methods available at the top level
include Drzyr::Dsl
