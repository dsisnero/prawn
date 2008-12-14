module Prawn
  class Formatter

    class Instruction
      attr_reader :state, :ascent

      def initialize(state)
        @state = state
        state.font.size(state.font_size) do
          @height = state.font.height
          @ascent = state.font.ascender
        end
      end

      def spaces
        0
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

      def force_break?
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
        state.font.normalize_encoding(@text)
      end

      def spaces
        @spaces ||= @text.scan(/ /).length
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
        @break = @text =~ /[-—\s]/
      end

      def discardable?
        return @discardable if defined?(@discardable)
        @discardable = (@text =~ /\s/)
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
        state.apply!(draw_state[:text], draw_state[:cookies])

        text = state.font.metrics.convert_text(@text, options)

        draw_state[:text].show(text)
        draw_state[:x] += width

        if options[:align] == :justify
          draw_state[:x] += draw_state[:padding] * spaces
        end
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
        draw_state[:text].move(draw_state[:x] - draw_state[:last_x], 0)
        draw_state[:last_x] = draw_state[:x]
      end
    end

    class LineBreakInstruction < Instruction
      def force_break?
        true
      end

      def break?
        true
      end

      def discardable?
        false
      end

      def draw(document, draw_state, options={})
        flush(document, draw_state, options)
      end
    end

    class ParagraphStartInstruction < Instruction
      def width
        state.font_size * 3
      end

      def draw(document, draw_state, options={})
        flush(document, draw_state, options)
        draw_state[:x] += width
        draw_state[:text].move(draw_state[:x] - draw_state[:last_x], 0)
        draw_state[:last_x] = draw_state[:x]
      end
    end

    class ParagraphEndInstruction < Instruction
      def force_break?
        true
      end

      def break?
        true
      end

      def draw(document, draw_state, options={})
        flush(document, draw_state, options)
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
          x = draw_state[:real_x]
          y = draw_state[:real_y] + draw_state[:y] + height

          label, destination = case @name
            when nil then return
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
      def self.pause(state, document, draw_state, options)
        save = new(state).draw(document, draw_state, options)
        draw_state[:link_stack].push(save) if save
      end

      def draw(document, draw_state, options={})
        flush(document, draw_state, options)

        link_state = (draw_state[:link_stack] || []).pop

        if link_state
          x1 = draw_state[:real_x] + link_state.last
          x2 = draw_state[:real_x] + draw_state[:x]
          y = draw_state[:real_y] + draw_state[:y]

          rect = [x1, y + state.font.descender - state.font.line_gap, x2, y + height]
          document.link_annotation(rect, :Dest => link_state.first, :Border => [0, 0, 0])
        end

        return link_state
      end
    end

  end
end
