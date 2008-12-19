require 'prawn/formatter/instructions/base'

module Prawn
  module Formatter
    module Instructions

      class TagOpen < Base
        attr_reader :tag

        def initialize(state, tag)
          super(state)
          @tag = tag
        end

        def width
          state.text_indent || 0
        end

        def draw(document, draw_state, options={})
          flush(document, draw_state)

          draw_text_indent(document, draw_state)
          draw_destination(document, draw_state)
          draw_link(document, draw_state)
        end

        def start_box?
          @tag[:style][:display] == :block
        end

        def style
          @tag[:style]
        end

        private

          def draw_text_indent(document, draw_state)
            return unless start_box?

            draw_state[:dx] += state.text_indent
            draw_state[:text].move_to(draw_state[:dx], draw_state[:dy])
          end

          def draw_destination(document, draw_state)
            return unless tag[:options][:anchor]

            x = draw_state[:real_x]
            y = draw_state[:real_y] + draw_state[:dy] + ascent

            label, destination = case tag[:options][:anchor]
              when /^zoom=([\d\.]+):(.*)$/
                [$2, document.dest_xyz(x, y, $1.to_f)]
              when /^fit:(.*)$/
                [$1, document.dest_fit]
              when /^fith:(.*)$/
                [$1, document.dest_fit_horizontally(y)]
              when /^fitv:(.*)$/
                [$1, document.dest_fit_vertically(x)]
              when /^fitb:(.*)$/
                [$1, document.dest_fit_bounds]
              when /^fitbh:(.*)$/
                [$1, document.dest_fit_bounds_horizontally(y)]
              when /^fitbv:(.*)$/
                [$1, document.dest_fit_bounds_vertically(x)]
              else
                [tag[:options][:anchor], document.dest_xyz(document.bounds.absolute_left, document.bounds.absolute_top, nil)]
              end

            document.add_dest(label, destination)
          end

          def draw_link(document, draw_state)
            return unless tag[:options][:target]

            draw_state[:link_stack] ||= []
            draw_state[:link_stack] << { :target => tag[:options][:target],
              :dx => draw_state[:dx] }

            draw_state[:on_wrap] ||= []
            draw_state[:on_wrap] << Proc.new { wrap_link(document, draw_state) }
          end

          def wrap_link(document, draw_state)
            TagClose.close(state, tag, draw_state)
            draw_state[:link_stack] << { :target => tag[:options][:target], :dx => 0 }
            draw_state[:on_wrap] << Proc.new { wrap_link(document, draw_state) }
          end
      end

    end
  end
end
