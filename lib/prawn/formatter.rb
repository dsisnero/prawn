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

      columns  = options[:columns] || 1
      gap      = options[:gap]     || 18
      width    = document.bounds.width.to_f / columns
      column   = 0

      until layout.done?
        lines = layout.fill(width - gap, document.bounds.height)
        draw_lines(document.bounds.absolute_left + column * width,
          document.bounds.absolute_top, width - gap,
          lines, options)

        unless layout.done?
          column += 1
          if column >= columns
            document.start_new_page
            column = 0
          end
        end
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
