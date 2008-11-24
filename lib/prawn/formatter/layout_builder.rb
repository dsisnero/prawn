require 'prawn/formatter/state'

module Prawn
  class Formatter
    class LayoutBuilder
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
      end

      class Segment
        attr_reader :state, :chunks
        attr_accessor :height

        def initialize(state, height)
          @state = state
          @height = height
          @chunks = []
        end

        def width
          chunks.inject(0) { |sum, chunk| sum + chunk.width }
        end

        def height
          chunks.all? { |chunk| chunk.ignore_at_eol? } ? 0 : @height
        end

        def to_s
          chunks.join
        end

        def inspect
          "#<Segment:%x width=%d height=%d chunks=%s>" % [object_id, width, height, chunks.inspect]
        end
      end

      class Chunk < Struct.new(:width, :text)
        # Because segments are split on whitespace, any chunk that
        # contains whitespace will be entirely whitespace and will
        # represent a chunk where a line may be broken.
        def line_break?
          text =~ /\s/
        end

        def ignore_at_eol?
          text =~ /\s/
        end

        def to_s
          text
        end

        def inspect
          "#{text.inspect}:#{width}"
        end
      end

      def self.layout(document, parser, line_width, options={})
        new(document, parser, line_width, options).lines
      end

      attr_reader :lines

      def initialize(document, parser, line_width, options={})
        @document = document
        @parser = parser
        @line_width = line_width.round
        @scan_pattern = options[:mode] == :character ? /./ : /\S+|\s+/
        @kerning = options[:kerning]
        @current_segment = @current_line = nil
        @lines = []

        @state = State.new(document,
          :font       => options[:font] || document.font,
          :font_size  => options[:size] || document.font.size,
          :font_style => options[:style] || :normal)

        layout!
      end

      private

        def layout!
          new_line!

          @parser.each do |token|
            case token[:type]
            when :text
              token[:text].lines.each_with_index do |line, index|
                new_line! if index > 0

                chunks = line.scan(@scan_pattern)
                chunks.each do |text|
                  width = @state.font.metrics.string_width(text, @state.font_size, :kerning => @kerning)
                  chunk = Chunk.new(width, text)

                  if (width + @current_line.width).round > @line_width
                    new_line!
                    next if chunk.ignore_at_eol?
                  end

                  @current_segment.chunks << chunk
                end
              end
            when :open
              case token[:tag]
              when :b then
                @state = @state.bold!
              when :i then
                @state = @state.italic!
              when :big then
                @state = @state.grow!
              when :small then
                @state = @state.shrink!
              when :font then
                @state = @state.change(:font => token[:options][:font],
                  :color => token[:options][:color], :size => token[:options][:size])
              else
                raise ArgumentError, "unknown tag type #{token[:tag]}"
              end
              add_segment!
            when :close
              @state = @state.previous
              add_segment!
            else
              raise ArgumentError, "[BUG] unknown token type #{token[:type].inspect} (#{token.inspect})"
            end
          end
        end

        def new_line!
          old_line = @current_line
          old_segment = @current_segment

          @current_line = Line.new
          add_segment!

          if old_segment
            while old_segment.chunks.any? && !old_segment.chunks.last.line_break?
              @current_segment.chunks.push(old_segment.chunks.pop)
            end
          end

          @lines << @current_line
        end

        def add_segment!
          @current_segment = Segment.new(@state, @state.font.height)
          @current_line.segments << @current_segment
        end
    end
  end
end
