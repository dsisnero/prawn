require 'prawn/formatter/instruction'
require 'prawn/formatter/line'
require 'prawn/formatter/state'

module Prawn
  class Formatter
    class LayoutBuilder
      def self.layout(document, lexer, line_width, options={})
        new(document, lexer, line_width, options).lines
      end

      attr_reader :lines

      def initialize(document, lexer, line_width, options={})
        @document = document
        @lexer = lexer
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

        # Reduces the tokens from the lexer into a series of instructions.
        def reduce!
          @instructions = []

          @lexer.each do |token|
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
              when :sup then
                @state = @state.sup!
              when :sub then
                @state = @state.sub!
              when :font then
                @state = @state.change(:font => token[:options][:font],
                  :color => token[:options][:color], :size => token[:options][:size])
              when :br then
                @instructions.push LineBreakInstruction.new(@state)
                @state = @state.change
              when :p then
                @instructions.push ParagraphStartInstruction.new(@state)
                @state = @state.change
              when :a then
                @instructions.push LinkStartInstruction.new(@state, token[:options][:name], token[:options][:href])
                @state = @state.change(:color => "0000ff")
              else
                raise ArgumentError, "unknown tag type #{token[:tag]}"
              end
            when :close
              case token[:tag]
              when :a then
                @instructions.push LinkEndInstruction.new(@state)
              when :p then
                @instructions.push ParagraphEndInstruction.new(@state)
              end
              @state = @state.prvious
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

            if instruction.force_break? || width >= @line_width
              hard_break = instruction.force_break? ||
                ((break_at || index) + 1 >= @instructions.length)
              @lines << Line.new(@instructions[start..(break_at || index)], hard_break)
              index = start = (break_at || index)+1
              break_at = nil
              width = 0
            else
              index += 1
            end
          end

          @lines << Line.new(@instructions[start..-1], true) if start < @instructions.length
        end
    end
  end
end
