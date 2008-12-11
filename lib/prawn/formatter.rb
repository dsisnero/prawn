require 'prawn/formatter/lexer'
require 'prawn/formatter/parser'
require 'prawn/formatter/layout_builder'

module Prawn
  class Formatter
    attr_reader :document
    attr_reader :layout
    attr_reader :options

    def initialize(document, text, options={})
      @document = document
      @options  = options
      @layout   = LayoutBuilder.new(document, text, options)
    end

    def wrap(wrap_options={})
      options  = @options.merge(wrap_options)

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

    def draw_lines(x, y, width, lines, options={})
      options[:align] ||= :left

      state = (options[:state] || {}).merge(:width => width, :last_x => 0, :y => y)
      state[:cookies] ||= {}

      document.text_object do |text|
        text.move(x, state[:y])
        state[:text] = text
        lines.each { |line| line.draw_on(document, state, options) }
      end

      state.delete(:text)
      return state
    end

  end
end
