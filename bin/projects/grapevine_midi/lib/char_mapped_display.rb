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
    char_box__em = @font.string_bb("m", x,y, vflip);
    ascender_height  = @font.ascender_height
    descender_height = @font.descender_height
    
    @char_width_pxs  = char_box__em.width
    @char_height_pxs = ascender_height - descender_height
    
    
    @char_grid = ("F" * @x_chars + "\n") * @y_chars
    
    
    
    
    
    
    
    # 
    # set up information needed for text coloring shader
    # 
    
    load_shaders("char_display")
    
    
  end
  
  def reload_shader
    load_shaders("char_display")
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
      
      
      bgMesh_draw()
      
    ensure
      ofPopStyle()
      ofPopMatrix()
      
    end
    
    
    
    # TODO: need to make it so that each character can have a separate color
    screen_print(font: @font,
                 string: @char_grid,
                 position: origin+CP::Vec2.new(0,line_height*1),
                 z: 5)
    
  end
  
  
  
  
  
  
  
  module EnumHelper
    def enum_each_color_in_image_with_index(image)
      Enumerator.new do |yielder|
        w = image.width
        h = image.height
        
        w.times do |x|
          h.times do |y|
            pos = CP::Vec2.new(x,y)
            yielder.yield image.getColor(pos.x, pos.y), pos
          end
        end
      end
    end
  end
  
  
  private :fgText_getShader, :fgText_getTexture
  private :getColorPixels_bg, :getColorPixels_fg
  
  
  class ColorHelper_bgOnly
    include EnumHelper
    
    def initialize(display, image)
      @display = display
      @image = image
    end
    
    # iterate through every pixel in the image
    # DO NOT RETURN Enumeration - will not work as expected
    # (need to first build up additional indirection for pixel access)
    def each() # &block
      
    end
    
    # index is a CP::Vec2 encoding position
    def each_with_index() # &block
      @display.autoUpdateColor_bg(false)
      
      en = enum_each_color_in_image_with_index(@image)
      en.each do |color, pos|
        yield color, pos
        @display.setColor_bg(pos.x, pos.y, color)
      end
      
      @display.flushColors_bg()
      @display.autoUpdateColor_bg(true)
    end
    
    # manipulate color at a particular pixel
    def pixel(pos) # &block
      
      unless( pos.x >= 0 && pos.x < @display.x_chars && 
              pos.y >= 0 && pos.y < @display.y_chars
      )
        raise IndexError, "position #{pos} is out of bounds [w,h] = [#{@x_chars}, #{@y_chars}]"
      end
      
      
      color = @image.getColor(pos.x, pos.y)
      yield color, pos
      
      @display.setColor_bg(pos.x, pos.y, color)
      
    end
  end
  
  class ColorHelper_fgOnly
    include EnumHelper
    
    def initialize(display, image)
      @display = display
      @image = image
    end
    
    # iterate through every pixel in the image
    # DO NOT RETURN Enumeration - will not work as expected
    # (need to first build up additional indirection for pixel access)
    def each() # &block
      
    end
    
    # index is a CP::Vec2 encoding position
    def each_with_index() # &block
      @display.autoUpdateColor_fg(false)
      
      en = enum_each_color_in_image_with_index(@image)
      en.each do |color, pos|
        yield color, pos
        @display.setColor_fg(pos.x, pos.y, color)
      end
      
      @display.flushColors_fg()
      @display.autoUpdateColor_fg(true)
    end
    
    # manipulate color at a particular pixel
    def pixel(pos)
      
      unless( pos.x >= 0 && pos.x < @display.x_chars && 
              pos.y >= 0 && pos.y < @display.y_chars
      )
        raise IndexError, "position #{pos} is out of bounds [w,h] = [#{@x_chars}, #{@y_chars}]"
      end
      
      
      color = @image.getColor(pos.x, pos.y)
      yield color, pos
      
      @display.setColor_fg(pos.x, pos.y, color)
      
    end
  end
  
  class ColorHelper_bgANDfg
    include EnumHelper
    
    def initialize(display, bg, fg)
      @display = display
      @images = [bg, fg]
    end
    
    # iterate through every pixel in the image
    # DO NOT RETURN Enumeration - will not work as expected
    # (need to first build up additional indirection for pixel access)
    def each() # &block
      
    end
    
    # index is a CP::Vec2 encoding position
    def each_with_index() # &block
      @display.autoUpdateColor_bg(false)
      @display.autoUpdateColor_fg(false)
      
      
      bg_enum = enum_each_color_in_image_with_index(@images[0])
      fg_enum = enum_each_color_in_image_with_index(@images[1])
      
      loop do
        c1, p1 = bg_enum.next
        c2, p2 = fg_enum.next
        
        yield c1, p1, c2, p2
        # colors and positions are in-out arguments
        
        @display.setColor_bg(p1.x, p1.y, c1)
        @display.setColor_fg(p2.x, p2.y, c2)
      end
      # when Enumeration#next fails, it throws StopIteration exception, which breaks the loop (e.g., loops automatically catch this exception type)
      
      @display.flushColors_bg()
      @display.autoUpdateColor_bg(true)
      
      @display.flushColors_fg()
      @display.autoUpdateColor_fg(true)
    end
    
    # manipulate color at a particular pixel
    def pixel(pos) # &block |RubyOF::Color, RubyOF::Color, CP::Vec2|
      
      unless( pos.x >= 0 && pos.x < @display.x_chars && 
              pos.y >= 0 && pos.y < @display.y_chars
      )
        raise IndexError, "position #{pos} is out of bounds [w,h] = [#{@x_chars}, #{@y_chars}]"
      end
      
      pos.to_a.tap do |x,y|
        c1 = @images[0].getColor(x, y)
        c2 = @images[1].getColor(x, y)
        
        yield c1, c2, pos
        
        @display.setColor_bg(x, y, c1)
        @display.setColor_fg(x, y, c2)
      end
      
    end
  end
  
  
  def bg_colors
    return ColorHelper_bgOnly.new( self, getColorPixels_bg() )
  end
  
  def fg_colors
    return ColorHelper_bgOnly.new( self, getColorPixels_fg() )
  end
  
  def colors
    return ColorHelper_bgANDfg.new(self, 
      getColorPixels_bg(), getColorPixels_fg()
    )
  end
  
  
  # @display.bg_colors.each do |color|
    
  # end
  
  # @display.bg_colors.each_with_index do |color, pos|
    
  # end
  
  # @display.bg_colors.pixel Vec2.new(0,0) do |color|
    
  # end
  
  # @display.colors.pixel Vec2.new(0,0) do |bg_color, fg_color|
    
  # end
  
  # @display.colors.each do |bg_color, fg_color|
    
  # end
  
  # @display.colors.each_with_index do |bg_color, p1, fg_color, p2|
    
  # end
  
  
  
  
  # TODO: depreciate #background_color and #foreground_color
  
  # @display.background_color do |c|
  #   c.r, c.g, c.b, c.a = [255, 255, 255, 255]
  # end
  def background_color(char_pos, &block)
    puts "setting bg color @ #{char_pos}"
    
    color = getColor_bg(char_pos.x, char_pos.y)
    
    block.call(color)
    
    # autoUpdateColor_bg(false)
      setColor_bg(char_pos.x, char_pos.y, color)
    # flushColors_bg()
    # autoUpdateColor_bg(true)
  end
  
  def foreground_color(char_pos, &block)
    color = getColor_fg(char_pos.x, char_pos.y)
    
    block.call(color)
    
    # autoUpdateColor_fg(false)
      setColor_fg(char_pos.x, char_pos.y, color)
    # flushColors_fg()
    # autoUpdateColor_fg(true)
  end
  
  
  
  
  # TODO: should return some Enumerator to access the color control pixels in the range of the printed string (it is common to want to print and then also adjust the color)
  
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
  
  def screen_print(font:, string:, position:, z:1)
      shader = fgText_getShader()
      
      
      shader.begin()
      
      shader.setUniformTexture("trueTypeTexture", font.font_texture,   0)
      shader.setUniformTexture("fontColorMap",    fgText_getTexture(), 1)
      
      RubyOF::CPP_Callbacks.ofShader_bindUniforms(
        shader,
        "origin",   @uniform__origin.x,   @uniform__origin.y,
        "charSize", @uniform__charSize.x, @uniform__charSize.y
      )
      
      # shader.setUniform2f("origin",   )
      # shader.setUniform2f("charSize", )
      
      # p @uniform__charSize.to_a
      
      ofPushMatrix()
      ofPushStyle()
    begin
      ofTranslate(position.x, position.y, z)
      
      # ofSetColor(color)
      
      x,y = [0,0]
      vflip = true
      text_mesh = font.get_string_mesh(string, x,y, vflip)
      
      text_mesh.draw()
    ensure
      ofPopStyle()
      ofPopMatrix()
      
      # font.font_texture.unbind
      # @text_colors_gpu.unbind
      shader.end()
    end
    
  end
  
  def load_shaders(*args)
    shader = fgText_getShader()
    load_flag = RubyOF::CPP_Callbacks.ofShader_loadShaders(shader, args)
    # ^ have to use this callback and not RubyOF::Shader#load() in order to load from the proper directory
    
    if load_flag
      # puts "Ruby: shader loaded"
    else
      puts "ERROR: couldn't load shaders '#{args.inspect}'"
    end
  end
  
  
end
