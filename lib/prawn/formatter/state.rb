module Prawn
  class Formatter
    class State
      attr_reader :document
      attr_reader :previous

      attr_reader :font
      attr_reader :font_size
      attr_reader :font_style
      attr_reader :color
      attr_reader :rise

      def initialize(document, options={})
        @document = document
        @previous = options[:previous]

        if @previous
          @font       = @previous.font
          @font_size  = @previous.font_size
          @font_style = @previous.font_style
          @color      = @previous.color
          @kerning    = @previous.kerning?
          @rise       = @previous.rise
        end

        @font       = options[:font]       || @font
        @font_size  = options[:font_size]  || @font_size
        @font_style = options[:font_style] || @font_style || :normal
        @color      = options[:color]      || @color      || "000000"
        @kerning    = options.fetch(:kerning, @kerning)
        @rise       = options[:rise]       || @rise       || 0
      end

      def kerning?
        @kerning
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

        options = options.merge(:previous => self,
          :font => document.find_font(font.family || font.name, :style => style),
          :font_size => size, :font_style => style)

        self.class.new(document, options)
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

      def sup!
        change_font :size => font_size * 0.7, :rise => rise + font_size * 0.4
      end

      def sub!
        change_font :size => font_size * 0.7, :rise => rise - font_size * 0.3
      end

      def change(options={})
        font = document.find_font(options[:font], :style => font_style) if options[:font]
        color = options[:color] || color
        size = options[:size] || font_size
        self.class.new(document, :previous => self, :font => font, :color => color,
          :font_size => size)
      end

      def apply!(text_object, cookies)
        if cookies[:font] != [font.name, font_size]
          cookies[:font] = [font.name, font_size]
          document.font(font.name, :size => font_size)
          text_object.font(font.identifier, font_size)
        end

        if cookies[:color] != color
          cookies[:color] = color
          text_object.fill_color(color)
        end

        if cookies[:rise] != rise
          cookies[:rise] = rise
          text_object.rise(rise || 0)
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
