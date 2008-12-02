module Prawn
  class Formatter

    class Instruction
      attr_reader :state

      def initialize(state)
        @state = state
        @height = state.font.height
      end

      def width(*args)
        0
      end

      def height(*args)
        @height
      end

      def break?
        false
      end

      def stretchable?
        false
      end

      def discardable?
        false
      end

      def flush(document, draw_state, options={})
        if draw_state[:accumulator]
          draw_state[:accumulator].draw!(document, draw_state, options)
          draw_state.delete(:accumulator)
        end
      end
    end

    class TextInstruction < Instruction
      attr_reader :text

      def initialize(state, text)
        super(state)
        @text = text
      end

      def height(ignore_discardable=false)
        if ignore_discardable && discardable?
          0
        else
          @height
        end
      end

      def break?
        return @break if defined?(@break)
        @break = @text =~ /[-\s]/
      end

      def discardable?
        return @discardable if defined?(@discardable)
        @discardable = (@text =~ /\s/)
      end

      def stretchable?
        return @stretchable if defined?(@stretchable)
        @stretchable = (@text =~ /\s/)
      end

      def width(type=:all)
        @width ||= @state.font.metrics.string_width(@text, @state.font_size, :kerning => @state.kerning?)

        case type
        when :discardable then discardable? ? @width : 0
        when :nondiscardable then discardable? ? 0 : @width
        else @width
        end
      end

      def to_s
        @text
      end

      def draw(document, draw_state, options={})
        if options[:force] 
          draw!(document, draw_state, options)
        else
          if draw_state[:accumulator] && draw_state[:accumulator].state != state
            flush(document, draw_state, options)
          end
          draw_state[:accumulator] ||= TextInstruction.new(state, "")
          draw_state[:accumulator].text << @text
        end
      end

      def draw!(document, draw_state, options={})
        state.apply!
        document.add_text_content(@text, draw_state[:x], document.y, options)
        #draw_state[:x] += draw_state[:padding] if options[:align] == :justify && stretchable?
        draw_state[:x] += width
      end
    end

    class StrutInstruction < Instruction
      attr_reader :width

      def initialize(state, width)
        super(state)
        @width = width
      end

      def draw(document, draw_state, options={})
        flush(document, draw_state, options)
        draw_state[:x] += width
      end
    end

    class LinkStartInstruction < Instruction
      def self.resume(document, draw_state)
        if draw_state[:link_stack] && draw_state[:link_stack].any?
          draw_state[:link_stack].last[1] = draw_state[:x]
        end
      end

      attr_reader :name, :target

      def initialize(state, name, target)
        super(state)
        @name, @target = name, target
      end

      def draw(document, draw_state, options={})
        flush(document, draw_state, options)
        draw_destination(document, draw_state)
        draw_link(document, draw_state)
      end

      private

        def draw_destination(document, draw_state)
          label, destination = case @name
            when nil then return
            when /^zoom=([\d\.]+):(.*)$/
              [$2, document.dest_xyz(draw_state[:x], document.y + height(true), $1.to_f)]
            when /^fit:(.*)$/
              [$1, document.dest_fit]
            when /^fith:(.*)$/
              [$1, document.dest_fit_horizontally(document.y + height(true))]
            when /^fitv:(.*)$/
              [$1, document.dest_fit_vertically(draw_state[:x])]
            when /^fitb:(.*)$/
              [$1, document.dest_fit_bounds]
            when /^fitbh:(.*)$/
              [$1, document.dest_fit_bounds_horizontally(document.y + height(true))]
            when /^fitbv:(.*)$/
              [$1, document.dest_fit_bounds_vertically(draw_state[:x])]
            else
              [@name, document.dest_xyz(document.bounds.left, document.bounds.top, nil)]
            end
          document.add_dest(label, destination)
        end

        def draw_link(document, draw_state)
          draw_state[:link_stack] ||= []
          if @target
            draw_state[:link_stack] << [@target, draw_state[:x]]
          else
            draw_state[:link_stack] << nil
          end
        end
    end

    class LinkEndInstruction < Instruction
      def self.pause(state, document, draw_state)
        save = new(state).draw(document, draw_state)
        draw_state[:link_stack].push(save) if save
      end

      def draw(document, draw_state, options={})
        flush(document, draw_state, options)

        link_state = (draw_state[:link_stack] || []).pop

        if link_state
          rect = [link_state.last, document.y + state.font.descender,
            draw_state[:x], document.y + height(true)]
          document.link_annotation(rect, :Dest => link_state.first, :Border => [0, 0, 0])
        end

        return link_state
      end
    end

  end
end
