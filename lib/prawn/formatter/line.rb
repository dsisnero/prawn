module Prawn
  class Formatter

    class Line
      attr_reader :tokens

      def initialize(tokens)
        @tokens = tokens
        @tokens.pop while @tokens.last && @tokens.last.discardable?
        @spaces = @tokens.select { |token| token.stretchable? }.length
        @spaces = 1 if @spaces < 1
      end

      def width
        tokens.inject(0) { |sum, token| sum + token.width }
      end

      def height(include_blank=false)
        tokens.map { |token| token.height(include_blank) }.max
      end

      def draw_on(document, state, options={})
        document.move_text_position(height(true))

        case(options[:align]) 
        when :left
          state[:x] = document.bounds.absolute_left
        when :center
          state[:x] = document.bounds.absolute_left + (document.bounds.width - width) / 2.0
        when :right
          state[:x] = document.bounds.absolute_right - width
        when :justify
          state[:x] = document.bounds.absolute_left
          state[:padding] = (document.bounds.width - width) / @spaces
        end
                             
        LinkStartInstruction.resume(document, state)
        state[:accumulator] = nil

        tokens.each { |token| token.draw(document, state, options) }

        LinkEndInstruction.pause(tokens.last.state, document, state)

        document.move_text_position(options[:spacing]) if options[:spacing]
      end
    end

  end
end
