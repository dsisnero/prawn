require 'prawn/formatter/parser'
require 'prawn/formatter/layout_builder'

module Prawn
  class Formatter
    attr_reader :document
    attr_reader :parser

    def initialize(document, text)
      @document   = document
      @parser     = Parser.new(text)
    end

    def wrap(options={})
      lines = layout(document.bounds.right,
        :size => options[:size], :font_family => options[:font_family],
        :style => options[:style], :mode => options[:wrap],
        :kerning => options[:kerning])

      wrap_lines(lines, options)
    end

    def layout(line_width, options={})
      LayoutBuilder.layout(document, parser, line_width, options)
    end

    def wrap_lines(lines, options={})
      options[:align] ||= :left      
      active_link = nil

      lines.each do |line|
        document.move_text_position(line.height)
                         
        case(options[:align]) 
        when :left
          x = document.bounds.absolute_left
        when :center
          x = document.bounds.absolute_left + 
            (document.bounds.width - line.width) / 2.0
        when :right
          x = document.bounds.absolute_right - line.width
        end
                             
        line.segments.each do |segment|
          segment.state.apply!
          next if segment.chunks.empty?
          document.add_text_content(segment.to_s,x,document.y,options)
          x += segment.width
          document.move_text_position(options[:spacing]) if options[:spacing]
        end 
      end
    end  
          
  end
end
