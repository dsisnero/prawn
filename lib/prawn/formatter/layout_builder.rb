require 'prawn/formatter/chunk'
require 'prawn/formatter/line'
require 'prawn/formatter/segment'
require 'prawn/formatter/state'

module Prawn
  class Formatter
    class LayoutBuilder
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

        def metrics
          @state.font.metrics
        end

        def layout!
          new_line!

          @parser.each do |token|
            case token[:type]
            when :text
              token[:text].lines.each_with_index do |line, index|
                new_line! if index > 0

                chunks = line.scan(@scan_pattern)
                chunks.each do |text|
                  width = metrics.string_width(text, @state.font_size, :kerning => @kerning)
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
              when :a then
                @current_line.segments << LinkStartSegment.new(@state, token[:options][:name], token[:options][:href])
              else
                raise ArgumentError, "unknown tag type #{token[:tag]}"
              end
              add_segment!
            when :close
              if token[:tag] == :a
                @current_line.segments << LinkEndSegment.new(@state)
              else
                @state = @state.previous
              end
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
          @current_segment = Segment.new(@state)
          @current_line.segments << @current_segment
        end
    end
  end
end
