require 'prawn/formatter/instructions/text'
require 'prawn/formatter/instructions/tag_open'
require 'prawn/formatter/instructions/tag_close'
require 'prawn/formatter/lexer'
require 'prawn/formatter/line'
require 'prawn/formatter/state'

module Prawn
  module Formatter
    class Parser
      class TagError < RuntimeError; end

      attr_reader :document
      attr_reader :styles
      attr_reader :state

      def initialize(document, text, options={})
        @document = document
        @lexer = Lexer.new(text)
        @styles = options[:styles] || {}

        @state = State.new(document, :style => options[:style])

        @action = :start

        @saved = []
        @tag_stack = []
      end

      def next
        return @saved.pop if @saved.any?

        case @action
        when :start then start_parse
        when :text  then text_parse
        else raise "BUG: unknown parser action: #{@action.inspect}"
        end
      end

      def push(instruction)
        @saved.push(instruction)
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
              @tag_stack << @token
              @token[:style] = @styles[@token[:tag]] or raise TagError, "undefined tag #{@token[:tag]}"

              if @token[:style][:meta]
                @token[:style][:meta].each do |key, value|
                  @token[:options][value] = @token[:options][key]
                end
              end

              @state = @state.with_style(@token[:style])
              instruction = Instructions::TagOpen.new(@state, @token)
            when :close
              raise TagError, "closing #{@token[:tag]}, but no tags are open" if @tag_stack.empty?
              raise TagError, "closing #{@tag_stack.last[:tag]} with #{@token[:tag]}" if @tag_stack.last[:tag] != @token[:tag]

              instruction = Instructions::TagClose.new(@state, @tag_stack.pop)
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
            @position += 1
            Instructions::Text.new(@state, @token[:text][@position - 1])
          else
            @action = :start
            start_parse
          end
        end
    end
  end
end
