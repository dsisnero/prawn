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
        document.move_text_position(height(true))
        document.send(:add_content, "BT")

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
          document.send(:add_content, "#{state[:padding]} Tw")
        end

        document.send(:add_content, "#{state[:x]} #{document.y} Td")
        document.send(:add_content, "/#{document.font.identifier} #{document.font.size} Tf")

        LinkStartInstruction.resume(document, state)
        state[:accumulator] = nil

        tokens.each { |token| token.draw(document, state, options) }

        LinkEndInstruction.pause(tokens.last.state, document, state, options)

        document.send(:add_content, "ET")
        document.move_text_position(options[:spacing]) if options[:spacing]
      end
    end

  end
end
