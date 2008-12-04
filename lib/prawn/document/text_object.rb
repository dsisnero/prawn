module Prawn
  class Document

    module TextObject
      class Proxy
        RENDER_MODES = {
          :fill             => 0,
          :stroke           => 1,
          :fill_stroke      => 2,
          :invisible        => 3,
          :fill_clip        => 4,
          :stroke_clip      => 5,
          :fill_stroke_clip => 6,
          :clip             => 7
        }

        def initialize
          @content = nil
        end

        def open
          @content = "BT\n"
          self
        end

        def close
          @content << "ET"
          self
        end

        def move(dx,dy)
          @content << "#{dx} #{dy} Td\n"
          self
        end

        def next_line
          @content << "T*\n"
          self
        end

        def show(argument)
          instruction = argument.is_a?(Array) ? "TJ" : "Tj"
          @content << "#{Prawn::PdfObject(argument, true)} #{instruction}\n"
          self
        end

        def character_space(dc)
          @content << "#{dc} Tc\n"
          self
        end

        def word_space(dw)
          @content << "#{dw} Tw\n"
          self
        end

        def leading(dl)
          @content << "#{dl} TL\n"
          self
        end

        def font(identifier, size)
          @content << "/#{identifier} #{size} Tf\n"
          self
        end

        def render(mode)
          mode_value = RENDER_MODES[mode] || raise(ArgumentError, "unsupported render mode #{mode.inspect}, should be one of #{RENDER_MODES.keys.inspect}")
          @content << "#{mode_value} Tr\n"
          self
        end

        def rise(value)
          @content << "#{value} Ts\n"
          self
        end

        def to_s
          @content
        end

        def to_str
          @content
        end
      end

      def text_object
        object = Proxy.new

        if block_given?
          begin
            yield object.open
          ensure
            add_content(object.close)
          end
        end

        return object
      end
    end

  end
end
