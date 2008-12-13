module Prawn
  class Formatter

    class Line
      attr_reader :instructions
      attr_accessor :offset

      def initialize(instructions, hard_break)
        @instructions = instructions
        @length = instructions.length
        @length -= 1 while @length > 0 && @instructions[@length-1].discardable?

        @hard_break = hard_break

        @spaces = @instructions[0,@length].inject(0) { |sum, instruction| sum + instruction.spaces }
        @spaces = [1, @spaces].max

        @offset = 0
      end

      def hard_break?
        @hard_break
      end

      def width
        instructions[0,@length].inject(0) { |sum, instruction| sum + instruction.width }
      end

      # distance from top of line to baseline
      def ascent
        instructions.map { |instruction| instruction.ascent }.max || 0
      end

      def height(include_blank=false)
        instructions.map { |instruction| instruction.height(include_blank) }.max
      end

      def draw_on(document, state, options={})
        return if @length.zero?

        case(options[:align]) 
        when :left
          state[:x] = 0
        when :center
          state[:x] = (state[:width] - width) / 2.0
        when :right
          state[:x] = state[:width] - width
        when :justify
          state[:x] = 0
          state[:padding] = hard_break? ? 0 : (state[:width] - width) / @spaces
          state[:text].word_space(state[:padding])
        end

        relative_x = state[:x] - state[:last_x]

        state[:y] -= ascent
        relative_y = state[:y] - state[:last_y]

        state[:last_x] = state[:x]
        state[:last_y] = state[:y]

        state[:text].move(relative_x, relative_y)

        LinkStartInstruction.resume(document, state)
        state[:accumulator] = nil

        instructions[0,@length].each { |instruction| instruction.draw(document, state, options) }

        LinkEndInstruction.pause(instructions.last.state, document, state, options)

        state[:y] -= (options[:spacing] || 0) + (height - ascent)
#new_x = state[:width] + 10
#relative_x = new_x - state[:last_x]
#state[:last_x] = new_x
#state[:text].move(relative_x, 0)
#state[:text].show(self[:badness].to_s)
      end
    end

  end
end
