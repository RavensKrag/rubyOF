# Abstraction of a grid of characters used as a low-fi output device.

# Input 'mesh' is just a ofMesh object. It does not need to have the
# proper verticies set - those will be specified by the code here
# (and the underlying C++ callbacks, of course)
class CharMappedDisplay
  include RubyOF::Graphics
  
  attr_reader :char_width_pxs, :char_height_pxs
  
  def initialize(mesh, pixels, texture, font)
    @x_chars = 20*3
    @y_chars = 18*1
    
    @mesh = mesh
    @font = font
    
    
    # 
    # set up grids of characters and colors (foreground and background color)
    # 
    
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
    
    
    
    
    
    
    # 
    # set up information needed for text coloring shader
    # 
    
    @shader = RubyOF::Shader.new
    load_shader("char_display")
    
    
    
    # @text_colors_cpu = RubyOF::Pixels.new
    @text_colors_cpu = pixels
    # @text_colors_cpu.allocate(@char_width_pxs, @char_height_pxs)
    
    # @text_colors_gpu = RubyOF::Texture.new
    @text_colors_gpu = texture
    # @text_colors_gpu.loadData(@text_colors_cpu)
    
    
    
    
    
    # 
    # assign background and foreground colors
    # 
    
    @bg_colors.each_with_index do |c,i|
      RubyOF::CPP_Callbacks.set_char_display_bg_color(
        @mesh, i, c
      )
    end
    
    @fg_colors.each_with_index do |c,i|
      # @text_colors_cpu[i] = c
      # @text_colors_gpu.loadData(@text_colors_cpu)
    end
    
    
  end
  
  def reload_shader
    load_shader("char_display")
  end
  
  
  def draw(origin, z)
    @uniform__origin = origin
    @uniform__charSize = CP::Vec2.new(@char_width_pxs, @char_height_pxs)
    
    
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
    
    color = @fg_colors[char_pos]
    
    block.call(color)
    
    # @text_colors_cpu[char_pos] = color
    # @text_colors_gpu.loadData(@text_colors_cpu)
  end
  
  
  
  # mind the invisible newline character at the end of every line
  def print_string(char_pos, str)
  
      case char_pos
      when CP::Vec2
        pos = char_pos
        # puts pos
        
        
        start_x = pos.x.to_i
        start_y = pos.y.to_i
        start_i = start_x + start_y*(@x_chars+1)
        
        stop_x = start_x + str.length-1
        stop_y = start_y
        stop_i = start_i + stop_x - start_x
        
        range = start_i..stop_i
        # puts range
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
    
      @shader.begin()
      
      @shader.setUniformTexture("trueTypeTexture", font.font_texture, 0)
      @shader.setUniformTexture("fontColorMap",    @text_colors_gpu,  1)
      
      @shader.setUniform2i("origin",   @uniform__origin.x.to_i, @uniform__origin.y.to_i)
      @shader.setUniform2i("charSize", @uniform__charSize.x.to_i, @uniform__charSize.y.to_i)
      
      # p @uniform__charSize.to_a
      
      ofPushMatrix()
      ofPushStyle()
    begin
      ofTranslate(position.x, position.y, z)
      
      ofSetColor(color)
      
      x,y = [0,0]
      vflip = true
      text_mesh = font.get_string_mesh(string, x,y, vflip)
        
        @fg_colors.each_with_index do |c,i|
          # puts "vertex color: #{i}"
          # RubyOF::CPP_Callbacks.colorize_char_display_mesh(
          #   text_mesh, i, c
          # )
          
          # ^ Can't modify mesh because it's const.
          
        end
        
        
        # New approach:
          # bind an annotional texture. each pixel in the texture will specify the color of one character, based on that character's position on screen.
          
          # to do this I need to wrap the classes ofPixels (CPU-side image) and ofTexture (GPU-side image, as well as the ability the switch between the two.
          
          # https://openframeworks.cc/documentation/graphics/ofPixels/
        
        
        
        
      text_mesh.draw()
    ensure
      ofPopStyle()
      ofPopMatrix()
      
      # font.font_texture.unbind
      # @text_colors_gpu.unbind
      @shader.end()
    end
    
  end
  
  def load_shader(*args)
    load_flag = RubyOF::CPP_Callbacks.load_char_display_shaders(
      @shader, args
    )
    # ^ have to use this callback and not RubyOF::Shader#load() in order to load from the proper directory
    
    if load_flag
      # puts "Ruby: shader loaded"
    else
      puts "ERROR: couldn't load shaders '#{args.inspect}'"
    end
  end
  
  
end
