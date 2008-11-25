module Prawn
  class Formatter

    class Chunk
      attr_reader :width
      attr_reader :text

      def initialize(width, text)
        @width, @text = width, text
      end

      # Because segments are split on whitespace, any chunk that
      # contains whitespace will be entirely whitespace and will
      # represent a chunk where a line may be broken.
      def line_break?
        text =~ /\s/
      end

      def ignore_at_eol?
        text =~ /\s/
      end

      def to_s
        text
      end

      def inspect
        "#{text.inspect}:#{width}"
      end
    end

  end
end
