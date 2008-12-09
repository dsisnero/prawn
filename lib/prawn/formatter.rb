require 'prawn/formatter/lexer'
require 'prawn/formatter/parser'
require 'prawn/formatter/layout_builder'

module Prawn
  class Formatter
    attr_reader :document
    attr_reader :lexer

    def initialize(document, text)
      @document   = document
      @lexer      = Lexer.new(text)
    end

    def wrap(options={})
      parser = Parser.new(document, @lexer, options)
      layout = LayoutBuilder.new(parser)
      wrap_lines(layout.lines(document.bounds.right), options)
    end

    private

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
