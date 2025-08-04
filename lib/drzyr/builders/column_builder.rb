# frozen_string_literal: true

# lib/drzyr/builders/column_builder.rb

module Drzyr
  class ColumnBuilder
    attr_reader :columns

    def initialize(ui_builder)
      @ui_builder = ui_builder
      @columns = []
    end

    def column(&block)
      @columns << @ui_builder.capture_elements(&block)
    end
  end
end
