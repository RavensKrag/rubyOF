# Abstraction of a grid of characters used as a low-fi output device.


class RubyOF::Project::ImageFiller
  def fill(selector, color)
    case selector
    when CP::BB
      self.fill_bb(selector.l, selector.b, selector.r, selector.t, color)
    else
      raise "do not know how to fill based on #{selector.class}"
    end
  end
end

# Input 'mesh' is just a ofMesh object. It does not need to have the
# proper verticies set - those will be specified by the code here
# (and the underlying C++ callbacks, of course)
class RubyOF::Project::CharMappedDisplay
  include RubyOF::Graphics
  
  attr_reader :char_width_pxs, :char_height_pxs
  attr_reader :x_chars, :y_chars
  
  
  def setup(x_chars, y_chars, origin, bg_offset, bg_scale)
    setup_colors(x_chars, y_chars)
    
    
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
    font = self.font()
    @em_width = self.font().string_bb("m", x,y, vflip).width;
    @ascender_height  = font.ascender_height
    @descender_height = font.descender_height
    
    
    
    @char_width_pxs  = @em_width
    @line_height = font.line_height
    
    
    setup_text_grid(@x_chars, @y_chars)
    
    # @char_grid = ("F" * @x_chars + "\n") * @y_chars
    # # TODO: implement utf32 character grid @ c++ level in order to speed up character printing (this is the main bottleneck for printing characters to the display)
    
    
    
    
    # 
    # cache vectors used to iterate through character grid
    # 
    
    w = self.x_chars
    h = self.y_chars
    
    @char_grid_pts = Array.new(w*h)
    
    i = 0
    
    h.times do |y|
      w.times do |x|
        @char_grid_pts[i] = CP::Vec2.new(x,y)
        
        i += 1
      end
    end
    
    # NOTE: can not call #freeze on CP::Vec2 (at least not by default)
    
    
    
    
    # 
    # set up information needed for text coloring shader
    # 
    
    # load_shaders(bg_shader_name, fg_shader_name)
    # NOTE: shaders not loaded yet. code to do that is #load_shaders, called in Core.rb#on_update(scheduler)
    
    setup_transforms(origin.x, origin.y,
                     bg_offset.x, bg_offset.y,
                     bg_scale.x, bg_scale.y)
    
  end
  
  def load_shaders(bg_shader_name, fg_shader_name)
    fgFlag = nil
    bgFlag = nil
    
    fgText_getShader().tap do |s|
      fgFlag = RubyOF::CPP_Callbacks.ofShader_loadShaders(s, [fg_shader_name])
    end
    
    bgText_getShader().tap do |s|
      bgFlag = RubyOF::CPP_Callbacks.ofShader_loadShaders(s, [bg_shader_name])
    end
    
    return bgFlag && fgFlag
  end
  
  def fg_shader_loaded?
    shader = fgText_getShader()
    shader.isLoaded()
  end
  
  def bg_shader_loaded?
    shader = bgText_getShader()
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
  
  def draw()
    cpp_draw() # TODO: move origin point into draw
  end
  
  
  # new interface / workflow: 
  # + get pixel positions
  #   either all positions in the grid, or positions changed by printing text
  # + filter position data as necessary (use Enumerable #select / #reject)
  # + read / write to those pixel positions
  
  
  private :bgText_getShader
  private :fgText_getShader, :fgText_getTexture
  
  def each_position() # &block
    return enum_for(:each_position) unless block_given?
    
    
    @char_grid_pts.each do |pt|
      yield pt
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
  
  
  # call this once per frame from the core,
  # similar to how you call flush just once
  # instead of pushing color information immediately
  # NOTE: remesh now defined at C++ level
  def remesh
    cpp_remesh()
  end
  
  
  # mind the invisible newline character at the end of every line
  # => Enumerator over the positions in the grid that were written to
  #    (if no characters were written, return nil)
  def print_string(x,y, str)
    return if x < 0 or y < 0
    return if y >= @y_chars
    
    if x >= @x_chars
      # NO-OP
    else
      # puts str
      # clip some of the output string, s.t. everything fits
      # (if necessary)
      if x+str.length-1 >= @x_chars 
        # new_stop_x = @x_chars-1
        # new_stop_y = stop_y
        # new_stop_i = start_i + new_stop_x - start_x
        
        # range = start_i..new_stop_i
        
        # puts str
        
        # overhang = (x+str.length - @x_chars)
        # if overhang > 0
        # end
        # temp = str.each_character.to_a
        # str = temp.first(n).join('')
        
        
        str = str[(0)..(@x_chars-1 - x)]
        # ^ without this, text with wrap (because grid is row-major)
        
        # TODO: test string clipping
        # (tested old code, but not the new cpp grid)
      end
      
      cpp_print(x, y, str)
    end
    
    
    
    # # pts = 
    # #   range
    # #   .map{|i| [i % (@x_chars+1), i / (@x_chars+1)]}
    # #   .map{|x,y| @char_grid_pts[x+y*@x_chars] }
    
    # # pts = range.map{|i| @char_grid_pts[i] }
    
    # # convert i [index in character grid] to (x,y) coordinate pair
    # return Enumerator.new do |yielder|
    #   range.each do |i|
    #     yielder << @char_grid_pts[i]
    #   end
    # end
    
  end
  
  
  
  
  private
  
  
  # def load_shaders(*args)
  #   shader = fgText_getShader()
  #   load_flag = RubyOF::CPP_Callbacks.ofShader_loadShaders(shader, args)
  #   # ^ have to use this callback and not RubyOF::Shader#load() in order to load from the proper directory
    
  #   # if load_flag
  #   #   # puts "Ruby: shader loaded"
  #   # else
  #   #   puts "ERROR: couldn't load shaders '#{args.inspect}'"
  #   # end
  # end
  
  
end