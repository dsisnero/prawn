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

        layout!
      end

      private

        def layout!
          @lines = []

          line = []
          width = 0

          while (instruction = @parser.next)
            line.push(instruction)

            if instruction.break?
              width += instruction.width(:nondiscardable)
              break_at = line.length if width <= @line_width
              width += instruction.width(:discardable)
            else
              width += instruction.width
            end

            if instruction.force_break? || width >= @line_width
              break_at ||= line.length
              hard_break = instruction.force_break? || @parser.eos?

              @parser.push(line.pop) while line.length > break_at
              @lines << Line.new(line, hard_break)

              break_at = nil
              width = 0
              line = []
            end
          end

          @lines << Line.new(line, true) if line.any?
        end
    end
  end
end
