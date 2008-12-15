require 'prawn/formatter/instruction'
require 'prawn/formatter/lexer'
require 'prawn/formatter/line'
require 'prawn/formatter/state'

module Prawn
  class Formatter
    class Parser
      def initialize(document, text, options={})
        @document = document
        @lexer = Lexer.new(text)

        @state = State.new(document,
          :font       => options[:font] || document.font,
          :font_size  => options[:size] || document.font.size,
          :font_style => options[:style] || :normal,
          :color      => options[:color],
          :kerning    => options[:kerning])

        @between_paragraphs = false
        @action = :start
        @stack = []
      end

      def next
        return @stack.pop if @stack.any?

        case @action
        when :start then start_parse
        when :text  then text_parse
        else raise "BUG: unknown parser action: #{@action.inspect}"
        end
      end

      def push(instruction)
        @stack.push(instruction)
      end

      def peek
        save = self.next
        push(save) if save
        return save
      end

      def eos?
        peek.nil?
      end

      private

        def start_parse
          instruction = nil
          while (@token = @lexer.next)
            case @token[:type]
            when :text
              @position = 0
              instruction = text_parse
            when :open
              @between_paragraphs = false
              case @token[:tag]
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
                @state = @state.change(:font => @token[:options][:font],
                  :color => @token[:options][:color], :size => @token[:options][:size])
              when :br then
                instruction = LineBreakInstruction.new(@state)
                @state = @state.change
              when :p then
                instruction = ParagraphStartInstruction.new(@state)
                @state = @state.change
              when :a then
                instruction = LinkStartInstruction.new(@state, @token[:options][:name], @token[:options][:href])
                @state = @state.change(:color => "0000ff")
              when :u then
                instruction = UnderlineStartInstruction.new(@state)
                @state = @state.change
              else
                raise ArgumentError, "unknown tag type #{@token[:tag]}"
              end
            when :close
              case @token[:tag]
              when :a then
                instruction = LinkEndInstruction.new(@state)
              when :p then
                instruction = ParagraphEndInstruction.new(@state)
                @between_paragraphs = true
              when :u then
                instruction = UnderlineEndInstruction.new(@state)
              end
              @state = @state.previous
            else
              raise ArgumentError, "[BUG] unknown token type #{@token[:type].inspect} (#{@token.inspect})"
            end

            return instruction if instruction
          end

          return nil
        end

        def text_parse
          if @token[:text][@position]
            @action = :text
            instruction = TextInstruction.new(@state, @token[:text][@position])
            @position += 1

            if @between_paragraphs && instruction.discardable?
              text_parse
            else
              @between_paragraphs = false
              instruction
            end
          else
            @action = :start
            start_parse
          end
        end
    end
  end
end
