module Prawn
  class Formatter

    class Line
      attr_reader :segments

      def initialize
        @segments = []
      end

      def width
        segments.inject(0) { |sum, segment| sum + segment.width }
      end

      def height
        segments.map { |segment| segment.height }.max
      end

      def draw_on(document, state, options={})
        document.move_text_position(height)

        case(options[:align]) 
        when :left
          state[:x] = document.bounds.absolute_left
        when :center
          state[:x] = document.bounds.absolute_left + (document.bounds.width - width) / 2.0
        when :right
          state[:x] = document.bounds.absolute_right - width
        end
                             
        LinkStartSegment.resume(document, state)

        segments.each { |segment| segment.draw(document, state, options) }

        LinkEndSegment.continue(segments.last.state, document, state)

        document.move_text_position(options[:spacing]) if options[:spacing]
      end

      private

        def carry_link_over_line_break(document, state)
          save = LinkEndSegment.draw(document, state)
          state[:link_stack].push(save)
        end
    end

  end
end
