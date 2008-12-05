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

        class Start
          attr_reader :parent, :at
          attr_accessor :badness, :width

          def initialize(at, badness, parent=nil)
            @at = at
            @badness = badness + (parent ? parent.badness : 0)
            @parent = parent
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
          # Start at the very beginning. This will be the parent of all other
          # potential line breaks, and acts as the seed for the queue of
          # potential lines.
          lines = [Start.new(0,0)]

          # We loop over all the line starts we've found, trying to find the
          # best "path" through the paragraph that gives us optimal line
          # breaks. The "current" variable indicates which line start we're
          # currently investigating.
          current = 0

          # "best" tells us what the best "terminal" (end-of-paragraph) line
          # is, so far. When this routine finishes, we can trace from final
          # line, backwards through the lines it was spawned from, to determine
          # the optimal sequence of line breaks. If this is nil when the
          # routine finishes, then the threshold was too low and we should try
          # again with a higher threshold.
          best = nil

          while current < lines.length
            # For each potential line-start seen so far, we look at the tokens
            # after it, adding new potential lines to the "lines" list.
            lines[current].at.upto(@tokens.length-1) do |index|
              token = @tokens[index]

              # if this token represents a character or character-sequence
              # where the line can be broken (a space, a hyphen, etc.), then
              # we see if this really is a feasible place for a line break.
              if token.break?

                # if the token is non-discardable (a hyphen) and adding it
                # to the line would make the line too long, then we can't
                # break the line here, and all subsequent tokens will also be
                # invalid as line breaks following the current line break. So
                # we break out and try the next potential line in the queue.
                break if !token.discardable? && lines[current].width + token.width > @line_width

                # Add any non-discardable width to the length of the current
                # line. This adds hyphens and such, but not spaces.
                lines[current].width += token.width(:nondiscardable)

                # Compute what the "badness" of this line would be if it were
                # broken at this point. Basically, the more the a line has to
                # stretch to fit the full line width, the higher the badness,
                # and the less likely it is to be an optimal line break.
                badness = (@line_width - lines[current].width) ** 2

                # If the computed badness is within the acceptible tolerance,
                # then we add a new line start to the queue, where the line
                # starts immediately after this token.
                #
                # Also, If adding the badness to the current line gives a worse
                # score than the best one seen so far, don't bother adding
                # a new break, since the break is definitely not one of the
                # best.
                if badness <= tolerance && (best.nil? || badness + lines[current].badness < best.badness)
                  lines << Start.new(index+1, badness, lines[current])
                end

                # At this point, we try to add the discardable width of the
                # token to the current line. The discardable width is the
                # width of any spaces, etc.
                break if lines[current].width + token.width(:discardable) > @line_width
                lines[current].width += token.width(:discardable)

              elsif lines[current].width + token.width > @line_width
                if index == lines[current].at
                  # If the line has nothing in it, and yet the next token
                  # still won't fit on the line, then we are dealing with a
                  # word that is too long to be broken. In this case, just
                  # add the word to the line and move on. We penalize the
                  # current line with extra badness in this case, since the
                  # line is definitely suboptimal.
                  lines[current].badness += 10_000
                  lines[current].width = @line_width
                else
                  # if the line already has something in it, and adding the
                  # next token would make it too long for the line, then we
                  # just stop adding more tokens to this line, and start
                  # looking at the next potential line in the queue.
                  break
                end

              else
                lines[current].width += token.width
              end

              # If we've made it this far, and we're at the end of the list of
              # tokens, then the current line is a terminal one (it is the last
              # line of this paragraph). See if the score is better than the
              # best score we've seen so far.
              if index == @tokens.length-1 && (best.nil? || lines[current].badness < best.badness)
                best = lines[current]
              end
            end

            # Check out the next line in the queue
            current += 1
          end

          # If best is not nil, return it as the tail of the best sequence of
          # line breaks we could find. Otherwise, increase the tolerance and
          # search again.
          return best || find_breaks(tolerance+1000)
        end

        def layout!
          break_point = find_breaks

          last_line = Line.new(@tokens[break_point.at..-1])
          last_line.tokens << StrutInstruction.new(last_line.tokens.last.state, @line_width - last_line.width)

          @lines = [last_line]
          while break_point.parent
            @lines.unshift Line.new(@tokens[break_point.parent.at...break_point.at])
            break_point = break_point.parent
          end
        end
    end
  end
end
