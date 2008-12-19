require 'prawn/formatter/instructions/base'

module Prawn
  module Formatter
    module Instructions

      class TagClose < Base
        attr_reader :tag

        def initialize(state, tag)
          super(state)
          @tag = tag
        end

        def [](property)
          @tag[:style][property]
        end

        def draw(document, draw_state, options={})
          flush(document, draw_state)
          draw_link(document, draw_state)
        end

        def break?
          force_break?
        end

        def style
          @tag[:style]
        end

        def force_break?
          @tag[:style][:display] == :block || @tag[:style][:display] == :break
        end

        def end_box?
          @tag[:style][:display] == :block
        end

        private

          def draw_link(document, draw_state)
            return unless @tag[:options][:target]

            link_state = draw_state[:link_stack].pop
            x1 = draw_state[:real_x] + link_state.last
            x2 = draw_state[:real_x] + draw_state[:dx]
            y  = draw_state[:real_y] + draw_state[:dy]

            rect = [x1, y + state.font.descender, x2, y + ascent]
p rect
            document.link_annotation(rect, :Dest => link_state.first, :Border => [0,0,0])
          end
      end

    end
  end
end
