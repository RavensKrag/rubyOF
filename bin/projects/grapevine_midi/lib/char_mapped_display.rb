# Abstraction of a grid of characters used as a low-fi output device.

# Input 'mesh' is just a ofMesh object. It does not need to have the
# proper verticies set - those will be specified by the code here
# (and the underlying C++ callbacks, of course)
class CharMappedDisplay
  include RubyOF::Graphics
  
  attr_reader :char_width_pxs, :char_height_pxs
  
  def initialize(mesh, font)
    @x_chars = 20*3
    @y_chars = 18*1
    
    @mesh = mesh
    @font = font
    
    
    x,y = [0,0]
    vflip = true
    char_box__em = @font.string_bb("m", x,y, vflip);
    ascender_height  = @font.ascender_height
    descender_height = @font.descender_height
    
    @char_width_pxs  = char_box__em.width
    @char_height_pxs = ascender_height - descender_height
    
    
    @char_grid = ("F" * @x_chars + "\n") * @y_chars
    
    
    RubyOF::CPP_Callbacks.init_char_display_bg_mesh(
      @mesh, @x_chars,@y_chars
    )
    
    @bg_colors = (@x_chars*@y_chars).times.collect do
      RubyOF::Color.new.tap do |c|
        c.r, c.g, c.b, c.a = [100, 100, 100, 255]
      end
    end
    
    @fg_colors = (@x_chars*@y_chars).times.collect do
      RubyOF::Color.new.tap do |c|
        c.r, c.g, c.b, c.a = [255, 255, 255, 255]
      end
    end
    
    
    
    
    @bg_colors.each_with_index do |c,i|
      RubyOF::CPP_Callbacks.set_char_display_bg_color(
        @mesh, i, c
      )
    end
    
    @fg_colors.each_with_index do |c,i|
      # setForegroundColor(i,c)
    end
  end
  
  
  def draw(origin, z)
    line_height = 38
    
    x,y = [0,0]
    vflip = true
    position = origin + CP::Vec2.new(0,line_height*1)
    
    
    
    char_box__em = @font.string_bb("m", x,y, vflip);
    ascender_height  = @font.ascender_height
    descender_height = @font.descender_height
    
    
    
      ofPushMatrix()
      ofPushStyle()
    begin
      ofTranslate(position.x, position.y - ascender_height, z)
      
      ofScale(@char_width_pxs, @char_height_pxs, 1)
      @mesh.draw()
      
    ensure
      ofPopStyle()
      ofPopMatrix()
      
    end
    
    
    
    # TODO: need to make it so that each character can have a separate color
    screen_print(font: @font, color: @fg_colors[0],
                 string: @char_grid,
                 position: origin+CP::Vec2.new(0,line_height*1),
                 z: 5)
    
  end
  
  
  
  
  # @display.background_color do |c|
  #   c.r, c.g, c.b, c.a = [255, 255, 255, 255]
  # end
  def background_color(char_pos, &block)
    case char_pos
    when CP::Vec2
      pos = char_pos
      char_pos = pos.x.to_i + pos.y.to_i*(@x_chars)
      # no need to add 1 here, because this only counts visible chars
      # and disregaurds the invisible newline at the end of each line
    when Numeric
      # NO-OP
      # char_pos can just be used as-is
    end
    
    color = @bg_colors[char_pos]
    
    block.call(color)
    
    RubyOF::CPP_Callbacks.set_char_display_bg_color(
      @mesh, char_pos, color
    )
  end
  
  def foreground_color(char_pos, &block)
    color = @fg_colors[char_pos]
    
    block.call(color)
    
    # RubyOF::CPP_Callbacks.set_char_display_bg_color(
    #   @mesh, char_pos, color
    # )
  end
  
  
  
  # mind the invisible newline character at the end of every line
  def print_string(char_pos, str)
  
      case char_pos
      when CP::Vec2
        pos = char_pos
        puts pos
        
        
        start_x = pos.x.to_i
        start_y = pos.y.to_i
        start_i = start_x + start_y*(@x_chars+1)
        
        stop_x = start_x + str.length-1
        stop_y = start_y
        stop_i = start_i + stop_x - start_x
        
        range = start_i..stop_i
        puts range
          # range.size               (counts number of elements)
          # range.min   range.first
          # range.max   range.last
        
        return if start_y >= @y_chars # off the bottom
        return if start_y < 0         # off the top
        return if start_x < 0         # off the left edge
        
        if start_x >= @x_chars
          # NO-OP
        else
          if stop_x >= @x_chars 
            # clip some of the output string, s.t. everything fits
            
            # range.size
            
            new_stop_x = @x_chars-1
            new_stop_y = stop_y
            new_stop_i = start_i + new_stop_x - start_x
            
            new_range = start_i..new_stop_i
            
            @char_grid[new_range] = str[(0)..(new_range.size-1)]
            
          else
            # display the full string
            
            @char_grid[range] = str
          end
        end
        
        
      when Numeric
        range = (char_pos)..(char_pos+str.length-1)
        @char_grid[range] = str
      end
    
  end
  
  
  
  
  private
  
  def screen_print(font:, string:, position:, color:, z:1)
    
      font.font_texture.bind
    
      ofPushMatrix()
      ofPushStyle()
    begin
      ofTranslate(position.x, position.y, z)
      
      ofSetColor(color)
      
      x,y = [0,0]
      vflip = true
      text_mesh = font.get_string_mesh(string, x,y, vflip)
      text_mesh.draw()
    ensure
      ofPopStyle()
      ofPopMatrix()
      
      font.font_texture.unbind
    end
    
  end
  
  
end
