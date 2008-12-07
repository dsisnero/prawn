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
        @wrap = options[:wrap]
        @line_width = line_width
        @kerning = options[:kerning]
        @tolerance = options.fetch(:tolerance, 10)

        @state = State.new(document,
          :font       => options[:font] || document.font,
          :font_size  => options[:size] || document.font.size,
          :font_style => options[:style] || :normal,
          :color      => options[:color],
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
          attr_accessor :badness, :width, :stretchability

          def initialize(at, badness, parent=nil)
            @at = at
            @badness = badness + (parent ? parent.badness : 0)
            @parent = parent
            @width = 0
            @stretchability = 0
          end

          def reset!
            @width = @stretchability = 0
          end
        end

        # Reduces the tokens from the parser into a series of instructions.
        def reduce!
          @instructions = [StrutInstruction.new(@state, 36)]

          @parser.each do |token|
            case token[:type]
            when :text
              @instructions.concat(token[:text].map { |lex| TextInstruction.new(@state, lex) })
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
                @instructions.push LinkStartInstruction.new(@state, token[:options][:name], token[:options][:href])
                @state = @state.change(:color => "0000ff")
              else
                raise ArgumentError, "unknown tag type #{token[:tag]}"
              end
            when :close
              @instructions.push LinkEndInstruction.new(@state) if token[:tag] == :a
              @state = @state.previous
            else
              raise ArgumentError, "[BUG] unknown token type #{token[:type].inspect} (#{token.inspect})"
            end
          end
        end

        def layout!
          @lines = []

          width = 0
          start = 0
          break_at = nil
          index = 0

          while index < @instructions.length
            instruction = @instructions[index]

            if instruction.break?
              width += instruction.width(:nondiscardable)
              break_at = index if width <= @line_width
              width += instruction.width(:discardable)
            else
              width += instruction.width
            end

            if width >= @line_width
              @lines << Line.new(@instructions[start..(break_at || index)])
              index = start = (break_at || index)+1
              break_at = nil
              width = 0
            else
              index += 1
            end
          end

          @lines << Line.new(@instructions[start..-1]) if start < @instructions.length
        end
    end
  end
end
