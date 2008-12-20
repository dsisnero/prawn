require 'strscan'

module Prawn
  module Formatter
    class Lexer
      class InvalidFormat < RuntimeError; end

      def initialize(text)
        @scanner = StringScanner.new(text)
        @state = :start
      end

      def next
        if @scanner.eos?
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
          when :self_close then scan_self_close_state
          end
        end

        TEXT_PATTERN = /
            -+                    | # hyphens
            \xE2\x80\x94+         | # mdashes
            \s+                   | # whitespace
            [^-\xE2\x80\x94\s&<]+   # everything else
          /x

        def scan_start_state
          if @scanner.scan(/</)
            if @scanner.scan(%r(/))
              scan_end_tag
            else
              scan_open_tag
            end
          elsif @scanner.scan(/&/)
            scan_entity
          else
            pieces = []
            loop do
              chunk = @scanner.scan(TEXT_PATTERN) or break
              chunk = " " if chunk =~ /\s\s+/
              pieces << chunk
            end
            { :type => :text, :text => pieces }
          end
        end

        # TODO: is it worth fleshing this out with a full list of all recognized
        # HTML entities?
        ENTITY_MAP = {
          "lt"    => "<",
          "gt"    => ">",
          "amp"   => "&",
          "mdash" => "\xE2\x80\x94",
          "ndash" => "\xE2\x80\x93",
          "nbsp"  => "\xC2\xA0",
        }

        def scan_entity
          entity = @scanner.scan(/(?:#x?)?\w+/) or error("bad format for entity")
          @scanner.scan(/;/) or error("missing semicolon to terminate entity")

          text = case entity
            when /#(\d+)/ then [$1.to_i].pack("U*")
            when /#x([0-9a-f]+)/ then [$1.to_i(16)].pack("U*")
            else
              result = ENTITY_MAP[entity] or error("unrecognized entity #{entity.inspect}")
              result.dup
            end

          { :type => :text, :text => [text] }
        end

        def scan_open_tag
          tag = @scanner.scan(/\w+/) or error("'<' without valid tag")
          tag = tag.downcase.to_sym

          options = {}
          @scanner.skip(/\s*/)
          while !@scanner.eos? && @scanner.peek(1) =~ /\w/
            name = @scanner.scan(/\w+/)
            @scanner.scan(/\s*=\s*/) or error("expected assigment after option #{name}")
            if (delim = @scanner.scan(/['"]/))
              value = @scanner.scan(/[^#{delim}]*/)
              @scanner.scan(/#{delim}/) or error("expected option value to end with #{delim}")
            else
              value = @scanner.scan(/[^\s>]*/)
            end
            options[name.downcase.to_sym] = value
            @scanner.skip(/\s*/)
          end

          if @scanner.scan(%r(/))
            @self_close = true
            @tag = tag
            @state = :self_close
          else
            @self_close = false
            @state = :start
          end

          @scanner.scan(/>/) or error("unclosed tag #{tag.inspect}")

          { :type => :open, :tag => tag, :options => options }
        end

        def scan_end_tag
          tag = @scanner.scan(/\w+/).to_sym
          @scanner.skip(/\s*/)
          @scanner.scan(/>/) or error("unclosed ending tag #{tag.inspect}")
          { :type => :close, :tag => tag }
        end

        def scan_self_close_state
          @state = :start
          { :type => :close, :tag => @tag }
        end

        def error(message)
          raise InvalidFormat, "#{message} at #{@scanner.pos} -> #{@scanner.rest.inspect[0,50]}..."
        end
    end
  end
end
