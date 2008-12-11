require 'prawn/formatter/instruction'
require 'prawn/formatter/line'
require 'prawn/formatter/parser'
require 'prawn/formatter/state'

module Prawn
  class Formatter
    class LayoutBuilder
      attr_reader :document, :options

      def initialize(document, text, options={})
        @document = document
        @options  = options
        @parser = Parser.new(@document, text, options)
      end

      def done?
        @parser.eos?
      end

      def word_wrap(width, height=nil, &block)
        if height && block
          raise ArgumentError, "cannot specify both height and a block"
        elsif height
          block = Proc.new { |l, h| h > height }
        elsif block.nil?
          block = Proc.new { |l, h| false }
        end

        lines = []
        total_height = 0

        while (line = self.next(width))
          if block[line, total_height + line.height]
            unget(line)
            break
          end

          total_height += line.height
          lines.push(line)
        end

        return lines
      end

      def fill(x, y, width, fill_options={}, &block)
        lines = word_wrap(width, fill_options[:height], &block)
        document.draw_lines(x, y, width, lines, options.merge(fill_options))
      end

      def next(line_width)
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

      def unget(line)
        @parser.push(line.instructions.pop) while line.instructions.any?
      end
    end
  end
end
