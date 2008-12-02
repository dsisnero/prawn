require 'strscan'

module Prawn
  class Formatter
    class Parser
      class InvalidFormat < RuntimeError; end

      attr_reader :tokens

      def initialize(text)
        parse!(text)
      end

      def each
        tokens.each { |token| yield token }
      end

      private

        def parse!(text)
          @tokens = []
          stack = []

          scanner = StringScanner.new(text)
          while !scanner.eos?
            text = scanner.scan(/[^<&]+/)
            @tokens << { :type => :text, :text => text.scan(/-+|\s+|[^-\s]+/) } if text

            if scanner.scan(/</)
              parse_tag(scanner, stack)
            elsif scanner.scan(/&/)
              parse_entity(scanner)
            end
          end

          if stack.any?
            raise InvalidFormat, "string terminated with unclosed tags: #{stack.join(', ')}"
          end
        end

        # TODO: is it worth fleshing this out with a full list of all recognized
        # HTML entities?
        ENTITY_MAP = {
          "lt"  => "<",
          "gt"  => ">",
          "amp" => "&"
        }

        def parse_entity(scanner)
          entity = scanner.scan(/(?:#x?)?\w+/) or raise InvalidFormat, "bad format for entity at #{scanner.pos} -> #{scanner.rest.inspect}"
          scanner.scan(/;/) or raise InvalidFormat, "missing semicolon to terminate entity at #{scanner.pos} -> #{scanner.rest.inspect}"

          text = case entity
            when /#(\d+)/ then [$1.to_i].pack("U*")
            when /#x([0-9a-f]+)/ then [$1.to_i(16)].pack("U*")
            else
              result = ENTITY_MAP[entity]
              raise InvalidFormat, "unrecognized entity #{entity.inspect} at #{scanner.pos} -> #{scanner.rest.inspect}"
              result
            end

          @tokens << { :type => text, :text => [Lexeme.new(text)] }
        end

        class Lexeme
          def initialize(lexeme)
            @lexeme = lexeme
          end

          def break?
            return @break if defined?(@break)
            @break = @lexeme =~ /[-\s]/
          end

          def discardable?
            return @discardable if defined?(@discardable)
            @discardable = (@lexeme =~ /\s/)
          end

          def stretchable?
            return @stretchable if defined?(@stretchable)
            @stretchable = (@lexeme =~ /\s/)
          end

          def to_s
            @lexeme
          end
        end

        def parse_tag(scanner, stack)
          closed = scanner.scan(%r{/})
          tag = scanner.scan(/\w+/)
          raise InvalidFormat, "'<' without valid tag at #{scanner.pos} -> #{scanner.rest.inspect}" unless tag

          tag = tag.downcase.to_sym
          options = {}
          scanner.skip(/\s*/)
          while !scanner.eos? && scanner.peek(1) != ">"
            name = scanner.scan(/\w+/) or raise InvalidFormat, "expected option name at #{scanner.pos} -> #{scanner.rest.inspect}"
            scanner.scan(/\s*=\s*/) or raise InvalidFormat, "expected assigment after option name at #{scanner.pos} -> #{scanner.rest.inspect}"
            if (delim = scanner.scan(/['"]/))
              value = scanner.scan(/[^#{delim}]*/)
              scanner.scan(/#{delim}/) or raise InvalidFormat, "expected option value to end with #{delim} at #{scanner.pos} -> #{scanner.rest.inspect}"
            else
              value = scanner.scan(/[^\s>]*/)
            end
            options[name.downcase.to_sym] = value
            scanner.skip(/\s*/)
          end

          scanner.scan(/>/) or raise InvalidFormat, "unclosed tag #{tag.inspect} at #{scanner.pos} -> #{scanner.rest.inspect}"

          if closed
            raise InvalidFormat, "improperly nested tags (attempt to close #{stack.last.inspect} with #{tag.inspect}) at #{scanner.pos} -> #{scanner.rest.inspect}" if stack.empty? || stack.last != tag
            stack.pop
            @tokens << { :type => :close, :tag => tag }
          else
            stack.push(tag)
            @tokens << { :type => :open, :tag => tag, :options => options }
          end
        end
    end
  end
end
