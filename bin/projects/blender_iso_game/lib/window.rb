require 'fiber'

require 'nokogiri'
require 'json'
require 'yaml'

require 'uri' # needed to safely / easily join URLs

require 'pathname'
require 'fileutils'

require 'chipmunk'

require 'require_all'


current_file = Pathname.new(__FILE__).expand_path
LIB_DIR = current_file.parent

require LIB_DIR/'of_core_extensions.rb'
require LIB_DIR/'ofx_extensions.rb'
require LIB_DIR/'callbacks.rb'

require LIB_DIR/'helpers.rb'
# require_all LIB_DIR/'history'

require LIB_DIR/'nonblocking_error_output.rb'

require LIB_DIR/'live_code.rb'
require LIB_DIR/'core.rb'


PROJECT_DIR = Pathname.new(__FILE__).expand_path.parent.parent


class Window < RubyOF::Window
  include HelperFunctions
  
  attr_reader :cpp_ptr, :cpp_val
  
  def initialize
    @cpp_ptr  = Hash.new
    @cpp_val = Hash.new # TODO: anything passed by value should have a destructor (C++ level memory needs to be cleared on ruby GC)
    
    @window_geometry_file = PROJECT_DIR/'bin'/'data'/'window_geometry.yaml'
    
    window_geometry = YAML.load_file(@window_geometry_file)
    x,y,w,h = *window_geometry
    
    super("grapevine communication", w,h) # half screen
    self.position = GLM::Vec2.new(x, y)
    
    # ofSetEscapeQuitsApp false
    
    
    puts "ruby: Window#initialize"
  end
  
  def setup
    super()
    
    puts "ruby: Window#setup (project)"
    
    $nonblocking_error = NonblockingErrorOutput.new($stdout)
    
    @core = Core.new(self)
    @live_code = LiveCode.new @core, LIB_DIR/'core.rb'
    
    @live_code.setup()
  end
  
  def update
    # super()
    @live_code.update()
  end
  
  def draw
    # super()
    
    # puts "draw"
    @live_code.draw()
  end
  
  
  
  # delegate inputs to input handler
  INPUT_EVENTS = 
  [
    :key_pressed,
    :key_released,
    :mouse_moved,
    :mouse_pressed,
    :mouse_dragged,
    :mouse_released,
    :drag_event,
    
    # :mouse_released,
    # :mouse_scrolled,
  ]
  INPUT_EVENTS.each do |sym|
    define_method sym do |*args|
      # super(*args)
      # ^ Calls Ruby-defined callback functions, not the C++ ones.
      #   Useful for baseline debugging, but not otherwise necessary
      
      # @input_queue << [sym, args]
      
      @live_code.send sym, *args
      
    end
  end
  
  
  
  
  def on_exit
    super()
    
    @live_code.on_exit
    
    # --- Save data
    pt = self.position()
    dump_yaml [pt.x, pt.y, self.width, self.height] => @window_geometry_file
    
    # --- Clear Ruby-level memory
    GC.start
    
    puts "FINISHED!"
    
  end
  
  
  
  
  
  
  
  # NOTE: regaurdless of if you copy the values over, or copy the color object, the copying slows things down considerably if it is done repetedly. Need to either pass one pointer from c++ side to Ruby side, or need to wrap ofParameter and use ofParameter#makeReferenceTo to ensure that the same data is being used in both places.
  # OR
  # you could use ofParameter#addListener to fire an event only when the value is changed (that could work)
    # May still want to bind ofParameter on the Ruby side, especially if I can find a way to allow for setting event listeners in Ruby.
  # def font_color=(color)
  #   p color
  #   # puts color
  #   # 'r g b a'.split.each do |channel|
  #   #   @font_color.send("#{channel}=", color.send(channel))
  #   # end
  #   @font_color = color
  #   @font_color.freeze
  # end
  
  # direct access to data used on the C++ side
  def recieve_cpp_pointer(name, data)
    @cpp_ptr[name] = data
  end
  
  # copy of the data from the C++ side
  def recieve_cpp_value(name, data)
    @cpp_val[name] = data
  end
  
  
  private
  
  
  # get hash of screen size info using xrandr
  def read_screen_size(screen_id)
    xrandr_description = `xrandr | grep "#{screen_id}"`
    # => "Screen 0: minimum 320 x 200, current 3840 x 2160, maximum 16384 x 16384\n"
    
    screen_size = 
      xrandr_description.chomp
      .split(':')
      .last.split(',')
      .collect{|x|
        property,x,_,y = x.split(' ');
        x = x.to_i
        y = y.to_i
        
        { property => [x,y] }
      }.reduce(:merge)
    
    return screen_size
  end
  
  
end
