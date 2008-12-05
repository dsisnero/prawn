require 'prawn/formatter/instruction'
require 'prawn/formatter/line'
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
        @tolerance = options.fetch(:tolerance, 1000)

        @state = State.new(document,
          :font       => options[:font] || document.font,
          :font_size  => options[:size] || document.font.size,
          :font_style => options[:style] || :normal,
          :kerning    => options[:kerning])

        reduce!
        layout!
      end

      private

        def metrics
          @state.font.metrics
        end

        class Break
          attr_reader :via, :badness, :start
          attr_accessor :width

          def initialize(start, badness, via=nil)
            @start = start
            @badness = badness
            @via = via
            @width = 0
          end
        end

        def reduce!
          @tokens = [StrutInstruction.new(@state, 36)]

          @parser.each do |token|
            case token[:type]
            when :text
              @tokens.concat(token[:text].map { |lex| TextInstruction.new(@state, lex) })
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
                @tokens.push LinkStartInstruction.new(@state, token[:options][:name], token[:options][:href])
                @state = @state.change(:color => "0000ff")
              else
                raise ArgumentError, "unknown tag type #{token[:tag]}"
              end
            when :close
              @tokens.push LinkEndInstruction.new(@state) if token[:tag] == :a
              @state = @state.previous
            else
              raise ArgumentError, "[BUG] unknown token type #{token[:type].inspect} (#{token.inspect})"
            end
          end
        end

        def find_breaks(tolerance=@tolerance)
          breaks = [Break.new(0,0)]
          current = 0

          best_score = 10_000
          best = nil

          while current < breaks.length
            breaks[current].start.upto(@tokens.length-1) do |index|
              token = @tokens[index]
              if token.break?
                break if breaks[current].width + token.width(:nondiscardable) > @line_width
                breaks[current].width += token.width(:nondiscardable)

                discriminant = @line_width - breaks[current].width
                badness = discriminant ** 2

                if badness <= tolerance
                  breaks << Break.new(index+1, badness, breaks[current])
                end

                break if breaks[current].width + token.width(:discardable) > @line_width
                breaks[current].width += token.width(:discardable)
              else
                break if breaks[current].width + token.width > @line_width
                breaks[current].width += token.width
              end

              if index == @tokens.length - 1
                score = 0
                node = breaks[current]

                loop do
                  score += breaks[current].badness
                  node = node.via
                  break unless node
                end

                if score < best_score
                  best_score = score
                  best = breaks[current]
                end
              end
            end

            current += 1
          end

          return best || find_breaks(tolerance+1000)
        end

        def layout!
          break_point = find_breaks

          last_line = Line.new(@tokens[break_point.start..-1])
          last_line.tokens << StrutInstruction.new(last_line.tokens.last.state, @line_width - last_line.width)

          @lines = [last_line]
          while break_point.via
            @lines.unshift Line.new(@tokens[break_point.via.start...break_point.start])
            break_point = break_point.via
          end
        end
    end
  end
end
