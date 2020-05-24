# Abstraction of a grid of characters used as a low-fi output device.

# Input 'mesh' is just a ofMesh object. It does not need to have the
# proper verticies set - those will be specified by the code here
# (and the underlying C++ callbacks, of course)
class CharMappedDisplay < RubyOF::Project::CharMappedDisplay
  include RubyOF::Graphics
  
  attr_reader :char_width_pxs, :char_height_pxs
  attr_reader :x_chars, :y_chars
  
  
  def initialize(font, x_chars, y_chars, origin, bg_offset, bg_scale)
    super()
    
    setup(x_chars, y_chars)
    @font = font
    
    
    # @x_chars = getNumCharsX()
    # @y_chars = getNumCharsY()
    @x_chars = x_chars
    @y_chars = y_chars
    
    
    
    # 
    # set up grids of characters and colors (foreground and background color)
    # 
    
    x,y = [0,0]
    vflip = true
    
    # OPTIMIZE: cache these values as long as @font remains the same
    @em_width = @font.string_bb("m", x,y, vflip).width;
    @ascender_height  = @font.ascender_height
    @descender_height = @font.descender_height
    
    
    
    @char_width_pxs  = @em_width
    @line_height = font.line_height
    
    
    @char_grid = ("F" * @x_chars + "\n") * @y_chars
    
    
    # 
    # set up information needed for text coloring shader
    # 
    
    
    @shader_name = "char_display" 
    load_shaders(@shader_name)
    
    
    setup_transforms(origin.x, origin.y,
                     bg_offset.x, bg_offset.y,
                     bg_scale.x, bg_scale.y)
    
    
    
    @cpp_ptr_bgColor = getBgColorPixels()
    @cpp_ptr_fgColor = getFgColorPixels()
  end
  
  def reload_shader
    load_shaders(@shader_name)
  end
  
  def shader_loaded?
    shader = fgText_getShader()
    shader.isLoaded()
  end
  
  # def update
  #   @glsl_live_loader ||= 
  #   LiveCode_GLSL.new do
  #     shader = fgText_getShader()
  #     load_flag = RubyOF::CPP_Callbacks.ofShader_loadShaders(shader, args)
  #     # ^ have to use this callback and not RubyOF::Shader#load() in order to load from the proper directory
      
  #     if load_flag
  #       # puts "Ruby: shader loaded"
  #     else
  #       puts "ERROR: couldn't load shaders '#{args.inspect}'"
  #     end
      
  #   end
    
  #   @glsl_live_loader.update
  #   # watch a particular filepath for changes to GLSL shaders
  #   # if either of the two files involved is updated, then reload the shaders
    
  #   load_shaders()
    
    
  # end
  
  # NOTE: do not move on z! that's not gonna give you the z-indexing you want! that's just a big headache!!! (makes everything weirdly blurry and in a weird position)
  # alias :cpp_draw :draw
  
  def draw()
      x = 0
      y = 0
      vflip = true
    text_mesh = @font.get_string_mesh(@char_grid, x,y, vflip)
    
    cpp_draw(text_mesh, @font.font_texture)
  end
  
  
  
  
  
  
  class Matrix2DEnum < Enumerator
    def initialize(w,h) # &block
      super() do |yielder|
        w.times do |x|
          h.times do |y|
            yielder << CP::Vec2.new(x,y)
          end
        end
      end
    end
  end
  
  module EnumHelper
    def gaurd_imageOutOfBounds(pos, x_size, y_size) # &block
      if( pos.x >= 0 && pos.x < x_size && 
          pos.y >= 0 && pos.y < y_size
      )
        yield
      else
        msg = "position #{pos} is out of bounds [w,h] = [#{x_size}, #{y_size}]"
        raise IndexError, msg
      end
    end
  end
  
  
  # new interface / workflow: 
  # + get pixel positions
  #   either all positions in the grid, or positions changed by printing text
  # + filter position data as necessary (use Enumerable #select / #reject)
  # + read / write to those pixel positions
  
  
  
  private :fgText_getShader, :fgText_getTexture
  
  def each_position() # &block
    enum = Matrix2DEnum.new(self.x_chars, self.y_chars)
    
    if block_given?
      
      enum.each do |pos|
        yield pos
      end
      
    else
      return enum
    end
  end
  
  private :getBgColorPixels, :getFgColorPixels
  
  class ColorHelper
    include EnumHelper
    
    def initialize(display, pixels)
      @display = display
      @pixels = pixels
    end
    
    def [](pos)
      gaurd_imageOutOfBounds pos, @display.x_chars, @display.y_chars do
        return @pixels.getColor_xy(pos.x, pos.y)
      end
    end
    
    def []=(pos, color)
      gaurd_imageOutOfBounds pos, @display.x_chars, @display.y_chars do
        return @pixels.setColor_xy(pos.x, pos.y, color)
      end
    end
  end
  
  def background
    return ColorHelper.new(self, @cpp_ptr_bgColor)
  end
  
  def foreground
    return ColorHelper.new(self, @cpp_ptr_fgColor)
  end
  
  # def setBG(pos, color)
  #   @cpp_ptr_bgColor.setColor_xy(pos.x, pos.y, color)
  # end
  
  # def setFG(pos, color)
  #   @cpp_ptr_fgColor.setColor_xy(pos.x, pos.y, color)
  # end
  
  
  
  # @display.each_position do |pos|
  #   @display.background_color[pos] = color;
  #   @display.foreground_color[pos] = color
    
  #   @display.background_color[pos]
  #   @display.foreground_color[pos]
    
  #   # @display.setColor_bg(pos, color)
  #   # @display.setColor_fg(pos, color)
  # end
  
  
  
  # mind the invisible newline character at the end of every line
  # => Enumerator over the positions in the grid that were written to
  #    (if no characters were written, return nil)
  def print_string(char_pos, str)
    range = nil
    
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
          
          range = start_i..new_stop_i
          
          @char_grid[range] = str[(0)..(range.size-1)]
          
        else
          # display the full string
          
          @char_grid[range] = str
        end
      end
      
      
    when Numeric
      range = (char_pos)..(char_pos+str.length-1)
      @char_grid[range] = str
    end
    
    
    # convert i [index in character grid] to (x,y) coordinate pair
    return Enumerator.new do |yielder|
      range.each do |i|
        x = i % (@x_chars+1)
        y = i / (@x_chars+1)
        
        yielder << CP::Vec2.new(x,y)
      end
    end
    
  end
  
  
  
  
  private
  
  
  def load_shaders(*args)
    shader = fgText_getShader()
    load_flag = RubyOF::CPP_Callbacks.ofShader_loadShaders(shader, args)
    # ^ have to use this callback and not RubyOF::Shader#load() in order to load from the proper directory
    
    # if load_flag
    #   # puts "Ruby: shader loaded"
    # else
    #   puts "ERROR: couldn't load shaders '#{args.inspect}'"
    # end
  end
  
  
end
