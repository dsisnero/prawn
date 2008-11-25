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
      lines = layout(document.bounds.right,
        :size => options[:size], :font_family => options[:font_family],
        :style => options[:style], :mode => options[:wrap],
        :kerning => options[:kerning])

      wrap_lines(lines, options)
    end

    def layout(line_width, options={})
      LayoutBuilder.layout(document, parser, line_width, options)
    end

    def wrap_lines(lines, options={})
      options[:align] ||= :left      
      state = {}
      lines.each { |line| line.draw_on(document, state, options) }
    end
  end
end
