require 'prawn/formatter/instruction'
require 'prawn/formatter/line'
require 'prawn/formatter/state'

module Prawn
  class Formatter
    class LayoutBuilder
      def initialize(parser)
        @parser = parser
      end

      def done?
        @parser.eos?
      end

      def fill(width, height)
        lines = []
        total_height = 0

        while (line = next_line(width))
          total_height += line.height
          if total_height > height
            @parser.push(line.instructions.pop) while line.instructions.any?
            break
          end
          lines.push(line)
          break if total_height + line.height > height
        end

        return lines
      end

      def next_line(line_width)
        line = []
        width = 0
        break_at = nil

        while (instruction = @parser.next)
          line.push(instruction)

          if instruction.break?
            width += instruction.width(:nondiscardable)
            break_at = line.length if width <= line_width
            width += instruction.width(:discardable)
          else
            width += instruction.width
          end

          if instruction.force_break? || width >= line_width
            break_at ||= line.length
            hard_break = instruction.force_break? || @parser.eos?

            @parser.push(line.pop) while line.length > break_at
            return Line.new(line, hard_break)
          end
        end

        Line.new(line, true) if line.any?
      end

      def lines(line_width)
        lines = []

        while (line = next_line(line_width))
          lines << line
        end

        return lines
      end
    end
  end
end
