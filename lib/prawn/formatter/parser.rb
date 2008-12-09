require 'strscan'

module Prawn
  class Formatter
    class Parser
      class InvalidFormat < RuntimeError; end

      attr_reader :tokens

      def initialize(text)
        @scanner = StringScanner.new(text)
        @stack = []
        @state = :start
      end

      def next_token
        if @scanner.eos?
          if @stack.any?
            raise InvalidFormat, "string terminated with unclosed tags: #{@stack.join(', ')}"
          end

          return nil
        else
          scan_next_token
        end
      end

      def each
        while (token = next_token)
          yield token
        end
      end

      private

        def scan_next_token
          case @state
          when :start then scan_start_state
          when :end_tag then scan_end_tag
          end
        end

        def scan_start_state
          if @scanner.scan(/</)
            scan_open_tag
          elsif @scanner.scan(/&/)
            scan_entity
          else
            text = @scanner.scan(/[^<&]+/) or abort "BUG! not sure how we got here"
            { :type => :text, :text => text.scan(/[-—]+|\s+|[^-\s]+/) }
          end
        end

        # TODO: is it worth fleshing this out with a full list of all recognized
        # HTML entities?
        ENTITY_MAP = {
          "lt"    => "<",
          "gt"    => ">",
          "amp"   => "&",
          "mdash" => "—",
          "ndash" => "–",
        }

        def scan_entity
          entity = @scanner.scan(/(?:#x?)?\w+/) or raise InvalidFormat, "bad format for entity at #{@scanner.pos} -> #{@scanner.rest.inspect}"
          @scanner.scan(/;/) or raise InvalidFormat, "missing semicolon to terminate entity at #{@scanner.pos} -> #{@scanner.rest.inspect}"

          text = case entity
            when /#(\d+)/ then [$1.to_i].pack("U*")
            when /#x([0-9a-f]+)/ then [$1.to_i(16)].pack("U*")
            else
              result = ENTITY_MAP[entity]
              if result.nil?
                raise InvalidFormat, "unrecognized entity #{entity.inspect} at #{@scanner.pos} -> #{@scanner.rest.inspect}"
              end
              result
            end

          { :type => :text, :text => text }
        end

        def scan_open_tag
          closed = @scanner.scan(%r{/})
          tag = @scanner.scan(/\w+/)
          raise InvalidFormat, "'<' without valid tag at #{@scanner.pos} -> #{@scanner.rest.inspect}" unless tag

          tag = tag.downcase.to_sym
          options = {}
          @scanner.skip(/\s*/)
          while !@scanner.eos? && @scanner.peek(1) =~ /\w/
            name = @scanner.scan(/\w+/) or raise InvalidFormat, "expected option name at #{@scanner.pos} -> #{@scanner.rest.inspect}"
            @scanner.scan(/\s*=\s*/) or raise InvalidFormat, "expected assigment after option name at #{@scanner.pos} -> #{@scanner.rest.inspect}"
            if (delim = @scanner.scan(/['"]/))
              value = @scanner.scan(/[^#{delim}]*/)
              @scanner.scan(/#{delim}/) or raise InvalidFormat, "expected option value to end with #{delim} at #{@scanner.pos} -> #{@scanner.rest.inspect}"
            else
              value = @scanner.scan(/[^\s>]*/)
            end
            options[name.downcase.to_sym] = value
            @scanner.skip(/\s*/)
          end

          @self_close = !closed && @scanner.scan(%r(/))

          @scanner.scan(/>/) or raise InvalidFormat, "unclosed tag #{tag.inspect} at #{@scanner.pos} -> #{@scanner.rest.inspect}"

          if closed
            raise InvalidFormat, "improperly nested tags (attempt to close #{@stack.last.inspect} with #{tag.inspect}) at #{@scanner.pos} -> #{@scanner.rest.inspect}" if @stack.empty? || @stack.last != tag
            @stack.pop
            { :type => :close, :tag => tag }
          else
            @state = @self_close ? :end_tag : :start
            @stack.push(tag)
            { :type => :open, :tag => tag, :options => options }
          end
        end

        def scan_end_tag
          @state = :start
          @stack.pop
          { :type => :close, :tag => tag }
        end
    end
  end
end
