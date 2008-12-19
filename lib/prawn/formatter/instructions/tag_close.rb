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
      end

    end
  end
end
