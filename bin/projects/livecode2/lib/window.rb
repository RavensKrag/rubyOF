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

require LIB_DIR/'helpers.rb'
# require_all LIB_DIR/'history'

require LIB_DIR / 'pipeline'


require LIB_DIR / 'history'

require LIB_DIR / 'nonblocking_error_output'
require LIB_DIR / 'live_code_loader'
require LIB_DIR / 'update_fiber'

require LIB_DIR / 'model_code'
require LIB_DIR / 'model_main_code'
require LIB_DIR / 'model_raw_input'
require LIB_DIR / 'model_core_space'
require LIB_DIR / 'UI_model'

require LIB_DIR / 'controller_state_machine'

require LIB_DIR / 'UI_InputController'
require LIB_DIR / 'Core_InputController'


require LIB_DIR / 'view_visualize_controller'



class Window < RubyOF::Window
  include HelperFunctions
  
  attr_reader :live, :data_dir, :camera
  attr_reader :font_color
  
  PROJECT_DIR = Pathname.new(__FILE__).expand_path.parent.parent
  def initialize
    @window_dimension_save_file = PROJECT_DIR/'bin'/'data'/'window_size.yaml'
    
    window_size = YAML.load_file(@window_dimension_save_file)
    w,h = *window_size
    
    # super("Youtube Subscription Browser", 1853, 1250)
    super("livecode v2.0", w,h) # half screen
    # super("Youtube Subscription Browser", 2230, 1986) # overlapping w/ editor
    
    # ofSetEscapeQuitsApp false
    
    puts "ruby: Window#initialize"
    
    
  end
  
  attr_reader :history
  # needed to interface with the C++ history UI code
  
  attr_reader :timeline_controller
  
  def setup
    super()
    
    @data_dir = PROJECT_DIR / 'bin' / 'data'
    # NOTE: All files should be located in @data_dir (Pathname object)
    
    
    
    
    # Initial output stream for LiveCode
    # (must be global - can't store in LiveCode due to History serialization)
    $nonblocking_error = NonblockingErrorOutput.new($stdout)
    
    
    # space containing main entities
    @core_space = History.new(Model::CoreSpace.new)
    
    # data for UI (various state machines)
    @ui_model = UI_Model.new
    
    
    # Input controller for UI. Acts based on inputs since last frame.
    @ui_input = LiveCode.new(
                  UI_InputController.new(@ui_model),
                  LIB_DIR / 'UI_InputController.rb')
    
    # Raw user input data (drives sequences)
    @input_history = History.new(LiveCode.new(
                             Model::RawInput.new,
                             LIB_DIR / 'model_raw_input.rb'))
    
    # Generate complex input events. Use history to see inputs across time.
    @core_input = LiveCode.new(
                    Core_InputController.new, # history passed on update
                    LIB_DIR / 'Core_InputController.rb')
    
    
    # code env with live reloading
    # (depends on @core_space and @input_history)
    @main_code =  History.new(
                    LiveCode.new(Model::MainCode.new,
                                 LIB_DIR / 'model_main_code.rb'))
    
    
    # the controller passes information between many objects
    @timeline_controller = 
          Controller.new(@input_history, @ui_input, @core_input,
                         @main_code, @core_space)
    
    # visualize info
    @main_view = LiveCode.new(View.new(@timeline_controller),
                              LIB_DIR / 'view_visualize_controller.rb')
    
    @input_queue = Array.new # queue up input events that happened this frame
    
    
    
    
    # irb outputs
    # ---
    # $stdout     puts output and similar
    # STDOUT       actual REPL line
    # src: https://rubytalk.org/t/redirecting-stderr-in-irb/56728/3
    @repl_thread = Thread.new do
      # Thread.current[:stdout] = STDOUT
      # Thread.current[:stderr] = STDERR
      
      x = @timeline_controller
      
      require 'irb'
      binding.irb
    end
    
    puts "setup complete"
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
    :mouse_scrolled,
  ]
  INPUT_EVENTS.each do |sym|
    define_method sym do |*args|
      # super(*args)
      # ^ Calls Ruby-defined callback functions, not the C++ ones.
      #   Useful for baseline debugging, but not otherwise necessary
      
      @input_queue << [sym, args]
    end
  end
  
  def update
    # super()
    
    
    # input_queue -> @ui_input
    Pipeline.open do |p| 
      p.start @input_queue
      p.pipe{|x| @ui_input.update x => self  }
    end
    
    # input_queue -> @input_history -> @core_input
    # @core_space -> @main_code ---> signal
    @timeline_controller.update self, @input_queue
    # (only updates @input_history when appropriate - not when time traveling)
    
    @input_queue = Array.new
    # Pass the entire queue object to controller.
    # Otherwise, the controller would have to make a deep clone of the queue.
    
    
    
    # FIXME: don't want to update input history all the time though - if execution is paused then only parse direct UI inputs
    
    # FIXME: need two modes - (1) step forward in a controlled manner, frame by frame and (2) run the simulation forward as fast as possible
    
    
    # FIXME: remove input history from the main controller, and into this controller
      # wait, but how does that work when you step back in time???
      # maybe this controller specifies how new inputs enter the queue, but then the other controller explains how inputs are processed? that makes sense
    
    
    @main_view.update
    
  end
  
  def draw
    # super()
    
    @main_view.draw
    
    # @timeline_controller.draw(self)
    # @main_code.inner.draw(self)
    # FIXME: figure out how to let @main_code draw to the screen
  end
  
  def on_exit
    super()
    
    # @live.on_exit unless @live.nil?
    
    # --- Save data
    dump_yaml [self.width, self.height] => @window_dimension_save_file
    
    # # --- Clear variables that might be holding onto OpenFrameworks pointers.
    # # NOTE: Cases where Chipmunk can hold onto OpenFrameworks data are dangerous. Must free Chimpunk data using functions like cpSpaceFree() during the lifetime of OpenFrameworks data (automatically called by Chipmunk c extension on GC), otherwise a segfault will occur. However, this segfault will occur inside Chipmunk code, which is very confusing.
    # @space = nil
    # @history = nil
    
    # wait for REPL to end
    puts "waiting for REPL to end..."
    @repl_thread.join
    puts "exiting"
    
    # --- Clear Ruby-level memory
    GC.start
    
  end
  
  
  
  
  
  
  # this is for drag-and-drop, not for mouse dragging
  def drag_event(files, position)
    p [files, position]
    
    #   ./lib/main.rb:41:in `show': Unable to convert glm::tvec2<float, (glm::precision)0>* (ArgumentError)
    # from ./lib/main.rb:41:in `<main>'
    
    # the 'position' variable is of an unknown type, leading to a crash
  end
  
  def show_text(pos, obj)
    # str = wordwrap(obj.to_s.split, 55)
    #       .collect{|line| line.join(" ") }.join("\n")
    
    # @text_buffer = Text.new(@font, str)
    # @text_buffer.text_color = @font_color
    
    # @text_buffer.body.p = pos
  end
  
  def clear_text_buffer
    # @text_buffer = nil
  end
  
  # wordwrap code below is from ruby docs or Enumerable
  # src: https://ruby-doc.org/core-2.5.1/Enumerable.html#method-i-partition
  
  # Word wrapping.  This assumes all characters have same width.
  def wordwrap(words, maxwidth)
    Enumerator.new {|y|
      # cols is initialized in Enumerator.new.
      cols = 0
      words.slice_before { |w|
        cols += 1 if cols != 0
        cols += w.length
        if maxwidth < cols
          cols = w.length
          true
        else
          false
        end
      }.each {|ws| y.yield ws }
    }
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
  
  
  # Set parameters from C++ by passing a pointer (technically, a reference),
  # wrapped up in a way that Ruby can understand.
  # 
  # name         name of the parameter being set
  # value_ptr    &data from C++, wrapped up in a Ruby class
  #              (uses the same class wrapper as normal Rice bindings)
  def set_gui_parameter(name, value_ptr)
    value_ptr.freeze
    
    # TODO: delegate core of this method to Loader, and then to the wrapped object inside. Want to be able to controll this dynamically.
    
    case name
      when "color"
        @font_color = value_ptr
      else
        msg = 
        [
          "",
          "Tried to set gui parameter, but I wasn't expecting this name.",
          "method call: set_gui_parameter(name, value_ptr)",
          "name:        #{name.inspect}",
          "value_ptr:   #{value_ptr.inspect}",
          "",
          "NOTE: set_gui_parameter() is often called from C++ code.",
          "      C++ backtrace information is not normally provided.",
          "",
          "NOTE: Sometimes C++ backtrace can be obtained using GDB",
          "      (use 'rake debug' to get a GDB prompt)"
        ].join("\n") + "\n\n\n"
        
        raise msg
    end
  end
  
  
  
  private
  
  def draw_debug_info(start_position, row_spacing, z=1)
    [
      "mouse: #{@p.inspect}",
      "window size: #{window_size.to_s}",
      "dt: #{ofGetLastFrameTime.round(5)}",
      "fps: #{ofGetFrameRate.round(5)}",
      "time (uSec): #{RubyOF::Utils.ofGetElapsedTimeMicros}",
      "time (mSec): #{RubyOF::Utils.ofGetElapsedTimeMillis}"
    ].each_with_index do |string, i|
      x,y = start_position
      y += i*row_spacing
      
      ofDrawBitmapString(string, x,y,z)
    end
  end
end
