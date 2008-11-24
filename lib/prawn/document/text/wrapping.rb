module Prawn
  class Document
    module Text
      module Wrapping

        class FormattingState
          attr_reader :previous

          attr_reader :font_family
          attr_reader :font_size
          attr_reader :font_style

          def initialize(options={})
            @previous = options[:previous]

            if @previous
              @font_family = @previous.font_family
              @font_size   = @previous.font_size
              @font_style  = @previous.font_style
            end

            @font_family = options[:font_family] if options[:font_family]
            @font_size   = options[:font_size]   if options[:font_size]
            @font_style  = options[:font_style]  if options[:font_style]
          end

          def bold?
            font_style == :bold || font_style == :bold_italic
          end

          def italic?
            font_style == :italic || font_style == :bold_italic
          end

          def change_font(options={})
            family = options[:family] || font_family
            size   = options[:size]   || font_size
            style  = add_style(options[:style])
            FormattingState.new(:previous => self,
              :font_family => family, :font_size => size, :font_style => style)
          end

          def bold!
            change_font :style => :bold
          end

          def italic!
            change_font :style => :italic
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

        Line = Struct.new(:width, :height, :segments)
        Segment = Struct.new(:width, :format, :text)

        def layout_text(content, line_width, options={})
          scan_pattern = options[:mode] == :character ? /./ : /\S+|\s+/                                    
          line_width = line_width.round
          state = FormattingState.new(:font_family => options[:font_family] || font.family,
            :font_size => options[:size] || font.size,
            :font_style => options[:style] || :normal)

          current_segment = current_line = nil
          lines = []

          new_line = Proc.new do
            current_segment = Segment.new(0, state, "")
            current_line = Line.new(0, 0, [current_segment])
            lines << current_line
          end

          add_text = Proc.new do |text, width|
            current_line.height = font.height if font.height > current_line.height
            current_segment.text << text
            current_segment.width += width
            current_line.width += width
          end

          add_segment = Proc.new do
            current_segment = Segment.new(0, state, "")
            current_line.segments << current_segment
          end

          new_line.call


          # It's a good v1, but it needs to be able to NOT break in the
          # middle of a word just because the font changes in the middle
          # of a word, e.g.:
          # 
          #    "<b>un</b>believable"
          #
          # That should never be broken between "un" and "believable",
          # unless there also happens to be a soft-hyphen there.
          content.each do |token|
            case token[:type]
            when :text
              token[:text].lines.each_with_index do |line, index|
                new_line.call if index > 0

                chunks = line.scan(scan_pattern)
                chunks.each do |chunk|
                  width = font.metrics.string_width(chunk, font.size, :kerning => options[:kerning])
                  if (width + current_line.width).round > line_width
                    new_line.call
                    add_text[chunk, width] if segment =~ /\S/
                  else
                    add_text[chunk, width]
                  end
                end
              end
            when :open
              case token[:tag]
              when :b then
                adopt_state(state = state.bold!)
              when :i then
                adopt_state(state = state.italic!)
              else
                raise ArgumentError, "unknown tag type #{token[:tag]}"
              end
              add_segment.call
            when :close
              adopt_state(state = state.previous)
              add_segment.call
            else
              raise ArgumentError, "[BUG] unknown token type #{token[:type].inspect} (#{token.inspect})"
            end
          end

          return lines
        end


        def wrap_formatted_content(content,options) 
          options[:align] ||= :left      

          lines = layout_text(content, bounds.right, :font_size => options[:size], :font_family => options[:font_family], :font_style => options[:style], :mode => options[:wrap], :kerning => options[:kerning])

          lines.each do |line|
            move_text_position(line.height)
                             
              case(options[:align]) 
              when :left
                x = @bounding_box.absolute_left
              when :center
                x = @bounding_box.absolute_left + 
                  (@bounding_box.width - line.width) / 2.0
              when :right
                x = @bounding_box.absolute_right - line.width
              end
                                 
            line.segments.each do |segment|
              adopt_state(segment.format)
              add_text_content(segment.text,x,y,options)
              x += segment.width
              move_text_position(options[:spacing]) if options[:spacing]
            end 
          end
        end  
          
        private

          def adopt_state(state)
            font(state.font_family, :size => state.font_size, :style => state.font_style)
          end

      end
    end
  end
end
