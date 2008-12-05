module Prawn
  class Formatter

    class Line
      attr_reader :tokens

      def initialize(tokens)
        @tokens = tokens
        @tokens.pop while @tokens.last && @tokens.last.discardable?
        @spaces = @tokens.inject(0) { |sum, token| sum + token.spaces }
        @spaces = [1, @spaces].max
      end

      def width
        tokens.inject(0) { |sum, token| sum + token.width }
      end

      def height(include_blank=false)
        tokens.map { |token| token.height(include_blank) }.max
      end

      def draw_on(document, state, options={})
        case(options[:align]) 
        when :left
          state[:x] = 0
        when :center
          state[:x] = (document.bounds.width - width) / 2.0
        when :right
          state[:x] = document.bounds.width - width
        when :justify
          state[:x] = 0
          state[:padding] = (document.bounds.width - width) / @spaces
          state[:text].word_space(state[:padding])
        end

        state[:y] -= height + (options[:spacing] || 0)

        relative_x = state[:x] - state[:last_x]
        state[:last_x] = state[:x]
        state[:text].move(relative_x, -(height + (options[:spacing] || 0)))

        LinkStartInstruction.resume(document, state)
        state[:accumulator] = nil

        tokens.each { |token| token.draw(document, state, options) }

        LinkEndInstruction.pause(tokens.last.state, document, state, options)
      end
    end

  end
end
