require 'prawn/formatter/parser'
require 'prawn/formatter/layout_builder'

module Prawn
  class Formatter
    attr_reader :document
    attr_reader :parser

    def initialize(document, text)
      @document   = document
      @parser     = Parser.new(text)
    end

    def wrap(options={})
      lines = layout(document.bounds.right, options)
      wrap_lines(lines, options)
    end

    def layout(line_width, options={})
      LayoutBuilder.layout(document, parser, line_width, options)
    end

    def wrap_lines(lines, options={})
      options[:align] ||= :left
      state = { :cookies => {}, :last_x => 0, :y => document.y }
      document.text_object do |text|
        text.move(document.bounds.absolute_left, state[:y])
        state[:text] = text
        lines.each { |line| line.draw_on(document, state, options) }
      end

      document.y = state[:y]
    end
  end
end
