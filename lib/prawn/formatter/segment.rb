module Prawn
  class Formatter

    class Segment
      attr_reader :state, :chunks
      attr_accessor :height

      def initialize(state)
        @state = state
        @height = @state && @state.font.height
        @chunks = []
      end

      def width
        chunks.inject(0) { |sum, chunk| sum + chunk.width }
      end

      def height(ignore_blank=false)
        return @height if ignore_blank
        chunks.all? { |chunk| chunk.ignore_at_eol? } ? 0 : @height
      end

      def draw(document, draw_state, options={})
        state.apply!
        return if chunks.empty?

        document.add_text_content(self.to_s, draw_state[:x], document.y, options)

        draw_state[:x] += width
      end

      def to_s
        chunks.join
      end

      def inspect
        "#<Segment:%x width=%d height=%d chunks=%s>" % [object_id, width, height, chunks.inspect]
      end
    end

    class LinkStartSegment < Segment
      def self.resume(document, draw_state)
        if draw_state[:link_stack] && draw_state[:link_stack].any?
          draw_state[:link_stack].last[1] = draw_state[:x]
        end
      end

      def initialize(state, name, target)
        @name = name
        @target = target
        super(state)
      end

      def draw(document, draw_state, options={})
        draw_destination(document, draw_state)
        draw_link(document, draw_state)
      end

      private

        def draw_destination(document, draw_state)
          label, destination = case @name
            when nil then return
            when /^zoom=([\d\.]+):(.*)$/
              [$2, document.dest_xyz(draw_state[:x], document.y + height(true), $1.to_f)]
            when /^fit:(.*)$/
              [$1, document.dest_fit]
            when /^fith:(.*)$/
              [$1, document.dest_fit_horizontally(document.y + height(true))]
            when /^fitv:(.*)$/
              [$1, document.dest_fit_vertically(draw_state[:x])]
            when /^fitb:(.*)$/
              [$1, document.dest_fit_bounds]
            when /^fitbh:(.*)$/
              [$1, document.dest_fit_bounds_horizontally(document.y + height(true))]
            when /^fitbv:(.*)$/
              [$1, document.dest_fit_bounds_vertically(draw_state[:x])]
            else
              [@name, document.dest_xyz(nil, nil, nil)]
            end
          document.add_dest(label, destination)
        end

        def draw_link(document, draw_state)
          draw_state[:link_stack] ||= []
          if @target
            draw_state[:link_stack] << [@target, draw_state[:x]]
          else
            draw_state[:link_stack] << nil
          end
        end
    end

    class LinkEndSegment < Segment
      def self.continue(state, document, draw_state)
        save = new(state).draw(document, draw_state)
        draw_state[:link_stack].push(save) if save
      end

      def initialize(state)
        super(state)
      end

      def draw(document, draw_state, options={})
        link_state = (draw_state[:link_stack] || []).pop

        if link_state
          rect = [link_state.last, document.y + state.font.descender,
            draw_state[:x], document.y + height(true)]
          document.link_annotation(rect, :Dest => link_state.first)
        end

        return link_state
      end
    end

  end
end
