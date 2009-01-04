# encoding: utf-8

# text.rb : Implements PDF text primitives
#
# Copyright May 2008, Gregory Brown. All Rights Reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.
require "zlib"
require "prawn/document/text/box"
require "prawn/formatter/layout_builder"

module Prawn
  class Document
    module Text
      
      # Draws text on the page. If a point is specified via the +:at+
      # option the text will begin exactly at that point, and the string is
      # assumed to be pre-formatted to properly fit the page.
      # 
      #   pdf.text "Hello World", :at => [100,100]
      #   pdf.text "Goodbye World", :at => [50,50], :size => 16
      #
      # When +:at+ is not specified, Prawn attempts to wrap the text to
      # fit within your current bounding box (or margin_box if no bounding box
      # is being used ). Text will flow onto the next page when it reaches
      # the bottom of the bounding box. Text wrap in Prawn does not re-flow
      # linebreaks, so if you want fully automated text wrapping, be sure to
      # remove newlines before attempting to draw your string.  
      #
      #   pdf.text "Will be wrapped when it hits the edge of your bounding box"
      #   pdf.text "This will be centered", :align => :center
      #   pdf.text "This will be right aligned", :align => :right     
      #
      #  Wrapping is done by splitting words by spaces by default.  If your text
      #  does not contain spaces, you can wrap based on characters instead:
      #
      #   pdf.text "This will be wrapped by character", :wrap => :character  
      #
      # If your font contains kerning pairs data that Prawn can parse, the 
      # text will be kerned by default.  You can disable this feature by passing
      # <tt>:kerning => false</tt>.
      #
      # === Text Positioning Details:
      #
      # When using the :at parameter, Prawn will position your text by its
      # baseline, and flow along a single line.
      #
      # When using automatic text flow, Prawn currently does a bunch of nasty
      # hacks to get things to position nicely in bounding boxes, table cells,
      # etc.
      #
      # For AFM fonts, the first line of text is positioned font.height below
      # the baseline.
      #
      # For TTF fonts, the first line is possitioned font.ascender below the
      # baseline.
      #
      # The issue here is that there are complex issues with determining the
      # size of the glyphs above and below the baseline in TTF that we haven't
      # figured out yet, and that AFM and TTF appear to handle things very
      # differently.
      #
      # The moral of the story is that if you want reliable font positioning
      # for your advanced needs, use :at, otherwise, just let Prawn do its
      # positioning magic for you, or investigate and help us get rid of this 
      # ugly issue.
      #
      # == Rotation
      #
      # Text can be rotated before it is placed on the canvas by specifying the
      # :rotate option. Rotation occurs counter-clockwise.
      #
      # == Encoding
      #
      # Note that strings passed to this function should be encoded as UTF-8.
      # If you get unexpected characters appearing in your rendered document, 
      # check this.
      #
      # If the current font is a built-in one, although the string must be
      # encoded as UTF-8, only characters that are available in WinAnsi
      # are allowed.
      #
      # If an empty box is rendered to your PDF instead of the character you 
      # wanted it usually means the current font doesn't include that character.
      #
      def text(text,options={})            
        # we'll be messing with the strings encoding, don't change the users
        # original string
        text = text.to_s.dup                      
        
        # we might also mess with the font
        original_font  = font.name   
              
        options = text_options.merge(options)
        process_text_options(options) 
         
        font.normalize_encoding(text) unless @skip_encoding        

        if options[:at]                
          x,y = translate(options[:at])            
          font.size(options[:size]) { add_text_content(text,x,y,options) }
        else
          if options[:rotate]
            raise ArgumentError, "Rotated text may only be used with :at" 
          end
          wrapped_text(text,options)
        end         

        font(original_font) 
      end 

      DEFAULT_STYLES = {
        :b      => { :font_weight => :bold },
        :i      => { :font_style => :italic },
        :u      => { :text_decoration => :underline },
        :br     => { :display => :break },
        :page   => { :display => :page_break },
        :p      => { :display => :block, :text_indent => "3em" },
        :sup    => { :vertical_align => :super, :font_size => "70%" },
        :sub    => { :vertical_align => :sub, :font_size => "70%" },
        :a      => { :meta => { :name => :anchor, :href => :target }, :color => "0000ff", :text_decoration => :underline },
        :center => { :display => :block, :text_align => :center },
        :h1     => { :display => :block, :text_align => :center, :font_size => "3em", :font_weight => :bold, :margin_bottom => "1em" },
        :h2     => { :display => :block, :text_align => :center, :font_size => "2em", :font_weight => :bold, :margin_bottom => "1em" },
        :h3     => { :display => :block, :text_align => :center, :font_size => "1.2em", :font_weight => :bold, :margin_bottom => "1em" },
      }.freeze

      def styles(update={})
        @styles ||= DEFAULT_STYLES.dup
        @styles.update(update)
      end

      def default_style
        { :font_family => font.family || font.name,
          :font_size   => font.size,
          :color       => fill_color }
      end

      def evaluate_measure(measure, options={})
        case measure
        when nil then nil
        when Numeric then return measure
        when Symbol then
          mappings = options[:mappings] || {}
          raise ArgumentError, "unrecognized value #{measure.inspect}" unless mappings.key?(measure)
          return evaluate_measure(mappings[measure], options)
        when String then
          operator, value, unit = measure.match(/^([-+]?)(\d+(?:\.\d+)?)(.*)$/)[1,3]

          value = case unit
            when "%" then
              relative = options[:relative] || 0
              relative * value.to_f / 100
            when "em" then
              # not a true em, but good enough for approximating. patches welcome.
              value.to_f * (options[:em] || font.size)
            when "", "pt" then return value.to_f
            when "pc" then return value.to_f * 12
            when "in" then return value.to_f * 72
            else raise ArgumentError, "unsupport units in style value: #{measure.inspect}"
            end

          current = options[:current] || 0
          case operator
          when "+" then return current + value
          when "-" then return current - value
          else return value
          end
        else return measure.to_f
        end
      end

      def draw_lines(x, y, width, lines, options={})
        real_x = x + bounds.absolute_left
        real_y = y + bounds.absolute_bottom

        state = options[:state] || {}
        return options[:state] if lines.empty?

        options[:align] ||= :left

        state = state.merge(:width => width,
          :x => x, :y => y,
          :real_x => real_x, :real_y => real_y,
          :dx => 0, :dy => 0)

        state[:cookies] ||= {}
        state[:pending_effects] ||= []

        text_object do |text|
          text.rotate(real_x, real_y, options[:rotate] || 0)
          state[:text] = text
          lines.each { |line| line.draw_on(self, state, options) }
        end

        state.delete(:text)

        return state
      end

      def layout(text, options={})
        helper = Formatter::LayoutBuilder.new(self, text, options)
        yield helper if block_given?
        return helper
      end

      def format(text, options={})
        layout(text, options) do |helper|
          self.y = helper.fill(bounds.left, y - bounds.absolute_bottom, options.merge(:width => bounds.width, :height => bounds.height))
        end
      end

      def paginate(text, options={})
        helper  = layout(text, options)

        columns = (options[:columns] || 1).to_i
        gap     = options[:gap]     || 18
        width   = bounds.width.to_f / columns
        column  = 0

        until helper.done?
          x = bounds.left + column * width
          y = self.y - bounds.absolute_bottom

          helper.fill(x, y, options.merge(:width => width - gap, :height => bounds.height))

          unless helper.done?
            column += 1
            if column >= columns
              start_new_page
              column = 0
            end
          end
        end
      end

      # A hash of configuration options, to be used globally by text().
      # 
      #   pdf.text_options.update(:size => 16, :align => :right)   
      #   pdf.text "Hello World" #=> Size 16 w. right alignment
      #
      def text_options
        @text_options ||= {}
      end 
                       
      def move_text_position(dy)   
         bottom = @bounding_box.stretchy? ? @margin_box.absolute_bottom :
                                            @bounding_box.absolute_bottom
         start_new_page if (y - dy) < bottom
         
         self.y -= dy       
      end

      private 
      
      def process_text_options(options)
        Prawn.verify_options [:style, :kerning, :size, :at, :wrap, 
                              :spacing, :align, :rotate ], options                               
        
        if options[:style]  
          raise "Bad font family" unless font.family
          font(font.family,:style => options[:style])
        end

        unless options.key?(:kerning)
          options[:kerning] = font.metrics.has_kerning_data?
        end                     

        options[:size] ||= font.size
      end

      def wrapped_text(text,options) 
        options[:align] ||= :left      

        font.size(options[:size]) do
          text = font.metrics.naive_wrap(text, bounds.right, font.size, 
            :kerning => options[:kerning], :mode => options[:wrap]) 

          lines = text.lines.to_a
                                                       
          lines.each_with_index do |e,i|         
            if font.metrics.type0?     
              move_text_position(font.ascender)
            else                                     
              move_text_position(font.height) 
            end                               
                           
            line_width = font.width_of(e)
            case(options[:align]) 
            when :left
              x = @bounding_box.absolute_left
            when :center
              x = @bounding_box.absolute_left + 
                (@bounding_box.width - line_width) / 2.0
            when :right
              x = @bounding_box.absolute_right - line_width 
            end
                               
            add_text_content(e,x,y,options)
            
            if font.metrics.type0? && i < lines.length - 1
              move_text_position(font.height - font.ascender)
            end
            
            move_text_position(options[:spacing]) if options[:spacing]
          end 
        end
      end  

      def add_text_content(text, x, y, options)
        chunks = font.metrics.encode_text(text,options)

        add_content "\nBT"
        if options[:rotate]
          rad = options[:rotate].to_i * Math::PI / 180
          arr = [ Math.cos(rad), Math.sin(rad), -Math.sin(rad), Math.cos(rad), x, y ]
          add_content "%.3f %.3f %.3f %.3f %.3f %.3f Tm" % arr
        else
          add_content "#{x} #{y} Td"
        end

        chunks.each do |(subset, string)|
          font.add_to_current_page(subset)
          add_content "/#{font.identifier_for(subset)} #{font.size} Tf"

          operation = options[:kerning] && string.is_a?(Array) ? "TJ" : "Tj"
          add_content Prawn::PdfObject(string, true) << " " << operation
        end
        add_content "ET\n"
      end
    end
  end
end
