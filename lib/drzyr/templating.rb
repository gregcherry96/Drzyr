# frozen_string_literal: true

require 'mustache'

module Drzyr
  # Module to handle Mustache template rendering
  module Templating
    def self.render(template_name, data)
      template_path = File.join(File.dirname(__FILE__), 'templates', "#{template_name}.mustache")
      template = File.read(template_path)
      Mustache.render(template, data)
    end
  end
end
