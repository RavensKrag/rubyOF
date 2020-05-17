# Abstraction of a grid of characters used as a low-fi output device.

# Input 'mesh' is just a ofMesh object. It does not need to have the
# proper verticies set - those will be specified by the code here
# (and the underlying C++ callbacks, of course)
class CharMappedDisplay < RubyOF::Project::CharMappedDisplay
  include RubyOF::Graphics
  
  attr_reader :char_width_pxs, :char_height_pxs
  attr_reader :x_chars, :y_chars
  
  
  def initialize(font, x_chars, y_chars)
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
  def draw(origin, bg_offset, bg_scale)
    x,y = [0,0]
    vflip = true
    position = origin + bg_offset
    
      ofPushMatrix()
      ofPushStyle()
    begin
      ofTranslate(position.x, position.y, 0)
      # ^ ascender height is the missing offset needed in the shader!
      #   Need to bind that and pass it in.
      #   Maybe can reduce some code duplication after that?
      
      ofScale(bg_scale.x, bg_scale.y, 1)
      
      
      bgMesh_draw()
      
    ensure
      ofPopStyle()
      ofPopMatrix()
      
    end
    
    
    
    
      shader = fgText_getShader()
      
      shader.begin()
      
      shader.setUniformTexture("trueTypeTexture", @font.font_texture,   0)
      shader.setUniformTexture("fontColorMap",    fgText_getTexture(), 1)
      
      RubyOF::CPP_Callbacks.ofShader_bindUniforms(
        shader,
        "origin",   origin.x, origin.y,
        "charSize", @ascender_height, @descender_height, @em_width
      )
      
      # shader.setUniform2f("origin",   )
      # shader.setUniform2f("charSize", )
      
      
      ofPushMatrix()
      ofPushStyle()
    begin
      # pos = origin + CP::Vec2.new(0,line_height*1) # this offset also in shader
      # ofTranslate(origin.x, origin.y, z)
      
      # x,y = [0,0]
      # vflip = true
      # # TODO: convert @char_grid to array of strings (less garbage?)
      # @char_grid.each_line.each_with_index do |line, i|
      #   pos = origin+CP::Vec2.new(0,i*@line_height)
      #   # @font.draw_string(line, pos.x, pos.y)
      #   # ^ if you render with draw_string, there's no weird line height errors
      #   #   but there are erros with drawing from mesh (position slightly off)
      #   #   is this a texture filtering error or similar? not sure, but may want to just use draw_string. how does the shader have to change? can I still use a shader?
        
      #   ofEnableBlendMode :alpha
      #   ofPushMatrix()
      #   ofTranslate(pos.x, pos.y, 0)
      #   @font.font_texture.bind
      #   text_mesh = @font.get_string_mesh(line, x,y, vflip)
      #   text_mesh.draw()
      #   @font.font_texture.unbind
      #   ofPopMatrix()
      # end
      
      
      
      ofEnableBlendMode :alpha
      ofPushMatrix()
      ofTranslate(origin.x, origin.y, 0)
      @font.font_texture.bind
      text_mesh = @font.get_string_mesh(@char_grid, x,y, vflip)
      text_mesh.draw()
      @font.font_texture.unbind
      ofPopMatrix()
      
    ensure
      ofPopStyle()
      ofPopMatrix()
      
      shader.end()
    end
  
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
  
  
  private :fgText_getShader, :fgText_getTexture
  
  class ColorHelper_bgOnly
    include EnumHelper
    
    def initialize(display)
      @display = display
    end
    
    # iterate through every pixel in the image
    # DO NOT RETURN Enumeration - will not work as expected
    # (need to first build up additional indirection for pixel access)
    def each() # &block
      
    end
    
    # index is a CP::Vec2 encoding position
    def each_with_index() # &block
      # @display.autoUpdateColor_bg(false)
      
      Matrix2DEnum.new(@display.x_chars, @display.y_chars).each do |pos|
        color = @display.getColor_bg(pos.x, pos.y)
        
        yield color, pos
        
        @display.setColor_bg(pos.x,pos.y, color)
      end
      
      # @display.flushColors_bg()
      # @display.autoUpdateColor_bg(true)
    end
    
    # manipulate color at a particular pixel
    def pixel(pos)
      gaurd_imageOutOfBounds(pos, @display.x_chars, @display.y_chars) do
        color = @display.getColor_bg(pos.x,pos.y)
        
        yield color
        
        @display.setColor_bg(pos.x,pos.y, color)
      end
    end
  end
  
  class ColorHelper_fgOnly
    include EnumHelper
    
    def initialize(display)
      @display = display
    end
    
    # iterate through every pixel in the image
    # DO NOT RETURN Enumeration - will not work as expected
    # (need to first build up additional indirection for pixel access)
    def each() # &block
      
    end
    
    # index is a CP::Vec2 encoding position
    def each_with_index() # &block
      # @display.autoUpdateColor_fg(false)
      
      Matrix2DEnum.new(@display.x_chars, @display.y_chars).each do |pos|
        color = @display.getColor_fg(pos.x, pos.y)
        
        yield color, pos
        
        @display.setColor_fg(pos.x,pos.y, color)
      end
      
      # @display.flushColors_fg()
      # @display.autoUpdateColor_fg(true)
    end
    
    # manipulate color at a particular pixel
    def pixel(pos)
      gaurd_imageOutOfBounds(pos, @display.x_chars, @display.y_chars) do
        color = @display.getColor_fg(pos.x,pos.y)
        
        yield color
        
        @display.setColor_fg(pos.x,pos.y, color)
      end
    end
  end
  
  
  class ColorHelper_bgANDfg
    include EnumHelper
    
    def initialize(display)
      @display = display
    end
    
    # iterate through every pixel in the image
    # DO NOT RETURN Enumeration - will not work as expected
    # (need to first build up additional indirection for pixel access)
    def each() # &block
      
    end
    
    # index is a CP::Vec2 encoding position
    def each_with_index() # &block
      # @display.autoUpdateColor_bg(false)
      # @display.autoUpdateColor_fg(false)
      
      
      Matrix2DEnum.new(@display.x_chars, @display.y_chars).each do |pos|
        bg_c = @display.getColor_bg(pos.x, pos.y)
        fg_c = @display.getColor_fg(pos.x, pos.y)
        
        # bg_c = RubyOF::Color.new
        # fg_c = RubyOF::Color.new
        
        
        yield bg_c, fg_c, pos
        # colors and positions are in-out arguments
        
        @display.setColor_bg(pos.x, pos.y, bg_c)
        @display.setColor_fg(pos.x, pos.y, fg_c)
      end
      
      
      # @display.flushColors_bg()
      # @display.autoUpdateColor_bg(true)
      
      # @display.flushColors_fg()
      # @display.autoUpdateColor_fg(true)
    end
    
    # manipulate color at a particular pixel
    def pixel(pos) # &block |RubyOF::Color, RubyOF::Color, CP::Vec2|
      gaurd_imageOutOfBounds(pos, @display.x_chars, @display.y_chars) do
        
        bg_c = @display.getColor_bg(pos.x, pos.y)
        fg_c = @display.getColor_fg(pos.x, pos.y)
        
        yield bg_c, fg_c
        
        @display.setColor_bg(pos.x, pos.y, bg_c)
        @display.setColor_fg(pos.x, pos.y, fg_c)
        
      end
    end
  end
  
  
  def bg_colors
    return ColorHelper_bgOnly.new(self)
  end
  
  def fg_colors
    return ColorHelper_fgOnly.new(self)
  end
  
  def colors
    return ColorHelper_bgANDfg.new(self)
  end
  
  def each_index() # &block
    enum = Matrix2DEnum.new(self.x_chars, self.y_chars)
    
    if block_given?
      
      enum.each do |pos|
        yield pos
      end
      
    else
      return enum
    end
  end
  
  
  # @display.bg_colors.each do |color|
  #   color.r, color.g, color.b, color.a = [255, 0, 0, 255]
  # end
  
  # @display.bg_colors.each_with_index do |color, pos|
  #   color.r, color.g, color.b, color.a = [255, 0, 0, 255]
  # end
  
  # @display.bg_colors.pixel Vec2.new(0,0) do |color|
  #   color.r, color.g, color.b, color.a = [255, 0, 0, 255]
  # end
  
  # @display.colors.pixel Vec2.new(0,0) do |bg_color, fg_color|
  #   color.r, color.g, color.b, color.a = [255, 0, 0, 255]
  # end
  
  # @display.colors.each do |bg_color, fg_color|
  #   color.r, color.g, color.b, color.a = [255, 0, 0, 255]
  # end
  
  # @display.colors.each_with_index do |bg_color, p1, fg_color, p2|
  #   color.r, color.g, color.b, color.a = [255, 0, 0, 255]
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
