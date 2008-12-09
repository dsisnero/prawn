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

      until layout.done?
        lines = layout.fill(document.bounds.width, document.bounds.height)
        draw_lines(document.bounds.absolute_left, document.bounds.absolute_top, document.bounds.right, lines, options)
        document.start_new_page unless layout.done?
      end
    end

    private

      def draw_lines(x, y, width, lines, options={})
        options[:align] ||= :left
        state = { :cookies => {}, :width => width, :last_x => 0, :y => y }

        document.text_object do |text|
          text.move(x, state[:y])
          state[:text] = text
          lines.each { |line| line.draw_on(document, state, options) }
        end

        return state[:y]
      end
  end
end
