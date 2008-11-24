module Prawn
  class Formatter
    class State
      attr_reader :document
      attr_reader :previous

      attr_reader :font
      attr_reader :font_size
      attr_reader :font_style
      attr_reader :color

      def initialize(document, options={})
        @document = document
        @previous = options[:previous]

        if @previous
          @font       = @previous.font
          @font_size  = @previous.font_size
          @font_style = @previous.font_style
          @color      = @previous.color
        end

        @font       = options[:font]       || @font
        @font_size  = options[:font_size]  || @font_size
        @font_style = options[:font_style] || @font_style || :normal
        @color      = options[:color]      || @color      || "000000"
      end

      def bold?
        font_style == :bold || font_style == :bold_italic
      end

      def italic?
        font_style == :italic || font_style == :bold_italic
      end

      def change_font(options={})
        font  = options[:font] || self.font
        size  = options[:size] || font_size
        style = add_style(options[:style])

        self.class.new(document, :previous => self,
          :font => document.find_font(font.family || font.name, :style => style),
          :font_size => size, :font_style => style)
      end

      def bold!
        change_font :style => :bold
      end

      def italic!
        change_font :style => :italic
      end

      def grow!
        change_font :size => font_size + 2
      end

      def shrink!
        change_font :size => font_size - 2
      end

      def change(options={})
        font = document.find_font(options[:font], :style => font_style) if options[:font]
        color = options[:color] || color
        size = options[:size] || font_size
        self.class.new(document, :previous => self, :font => font, :color => color,
          :font_size => size)
      end

      def apply!
        if document.font.name != font.name || document.font.size != font_size
          document.font(font.name, :size => font_size)
        end

        if document.fill_color != color
          document.fill_color(color)
        end
      end

      private

        def add_style(style)
          case style
          when nil then return font_style
          when :normal then return style
          when :bold then
            return :bold_italic if font_style == :italic
            return style
          when :italic then
            return :bold_italic if font_style == :bold
            return style
          when :bold_italic then
            return style
          else
            raise ArgumentError, "unknown font-style #{font_style.inspect}"
          end
        end
    end
  end
end
