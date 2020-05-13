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

require LIB_DIR/'ofx_extensions.rb'

require LIB_DIR/'helpers.rb'
# require_all LIB_DIR/'history'

require LIB_DIR/'input_handler.rb'
require LIB_DIR/'sequence_memory.rb'
require LIB_DIR/'char_mapped_display.rb'




class Window < RubyOF::Window
  include HelperFunctions
  
  PROJECT_DIR = Pathname.new(__FILE__).expand_path.parent.parent
  def initialize
    @cpp_ptr  = Hash.new
    @cpp_val = Hash.new
    
    @window_geometry_file = PROJECT_DIR/'bin'/'data'/'window_geometry.yaml'
    
    window_geometry = YAML.load_file(@window_geometry_file)
    x,y,w,h = *window_geometry
    
    super("grapevine communication", w,h) # half screen
    self.set_window_position(x, y)
    
    # ofSetEscapeQuitsApp false
    
    
    puts "ruby: Window#initialize"
    
    
    @input_handler = InputHandler.new
    
    # [
    #   ['x', 2, 72,     64, 0],
    #   ['d', 2, 72+7,   64, 0],
    #   ['h', 3, 72+2+7, 64, 0],
    #   ['c', 3, 72+3+7, 64, 0],
    #   ['n', 3, 72+7,   64, 0]
    # ].each do |char, channel, note, on_velocity, off_velocity|
    #   btn_id = char.codepoints.first
      
    #   @input_handler.register_callback(btn_id) do |btn|
    #     btn.on_press do
    #       puts "press #{char}"
          
    #       @cpp_ptr["midiOut"].sendNoteOn(channel, note, on_velocity)
    #     end
        
    #     btn.on_release do
    #       puts "release #{char}"
          
    #       @cpp_ptr["midiOut"].sendNoteOff(channel, note, off_velocity)
    #     end
        
    #     btn.while_idle do
          
    #     end
        
    #     btn.while_active do
          
    #     end
    #   end
    # end
    
    
    
    @midi_msg_memory = SequenceMemory.new
    
    
    
    @looper_mode = :idle
    @looper = Array.new
    
    btn_id = 'x'.codepoints.first
    @input_handler.register_callback(btn_id) do |btn|
      btn.on_press do
        case @looper_mode 
        when :record
          # record -> playback
          # => stop recording, and switch to playing back the saved recording
          @looper_end = RubyOF::Utils.ofGetElapsedTimeMillis()
          
          
          @looper_mode = :playback
          
        when :playback, :idle
          # playback -> record
          # => start a fresh recording
          @looper.clear
          @looper_fiber = nil
          
          
          @looper_mode = :record
        
        end
        
      end
      
      btn.on_release do
        
      end
      
      btn.while_idle do
        
      end
      
      btn.while_active do
        
      end
    end
    
    
    
  end
  
  def setup
    super()
    
    @first_draw = true
    
    
    
    @fonts = Hash.new
    
    @fonts[:monospace] = 
      RubyOF::TrueTypeFont.dsl_load do |x|
        x.path = "DejaVu Sans Mono"
        x.size = 23
        x.add_alphabet :Latin
        x.add_unicode_range :BlockElement
      end
    
    @fonts[:english] = 
      RubyOF::TrueTypeFont.dsl_load do |x|
        # TakaoPGothic
        x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
        x.size = 23
        x.add_alphabet :Latin
      end
     
    # @fonts[:japanese] = 
    #     RubyOF::TrueTypeFont.dsl_load do |x|
    #       # TakaoPGothic
    #       # ^ not installed on Ubunut any more, idk why
    #       # try the package "fonts-takao" or "ttf-takao" as mentioned here:
    #       # https://launchpad.net/takao-fonts
    #       x.path = "Noto Sans CJK JP Regular" # comes with Ubuntu
    #       x.size = 40
    #       x.add_alphabet :Latin
    #       x.add_alphabet :Japanese
    #     end
    
    
    
    @display = CharMappedDisplay.new(@fonts[:monospace], 20*3, 18*1)
    # @display.autoUpdateColor_bg(false)
    # @display.autoUpdateColor_fg(false)
    
    
    # clear out the garbage bg + test pattern fg
    @display.colors.each_with_index do |bg_c, fg_c, pos|
      bg_c.r, bg_c.g, bg_c.b, bg_c.a = ([(0.5*255).to_i]*3 + [255])
      fg_c.r, fg_c.g, fg_c.b, fg_c.a = ([(0.1*255).to_i]*3 + [255])
    end
    
    
    @display.print_string(5, "hello world!")
    .each do |pos|
      @display.bg_colors.pixel pos do |c|
         c.r, c.g, c.b, c.a = [0, 0, 255, 255]
      end
    end
    
    
    @display.print_string(CP::Vec2.new(55, 5), "spatial inputs~")
    @display.print_string(CP::Vec2.new(7, 5), "spatial inputs~")
    .each do |pos|
      @display.bg_colors.pixel pos do |c|
         c.r, c.g, c.b, c.a = [255, 0, 0, 255]
      end
    end
    
    @display.print_string(CP::Vec2.new(0, 17), "bottom clip")
    @display.print_string(CP::Vec2.new(0, 18), "this should not print")
    
    
    msg = "gets cut off somewhere in the middle"
    @display.print_string(CP::Vec2.new(30, 9), msg)
    .each do |pos|
      @display.bg_colors.pixel pos do |c|
        c.r, c.g, c.b, c.a = [255, 0, 0, 255]
      end
    end
    # ^ Enumerator stops at end of display where the text was clipped
    
    
    
    
    @display.colors.pixel CP::Vec2.new(10,10) do |bg_c, fg_c|
      bg_c.r, bg_c.g, bg_c.b, bg_c.a = [255, 0, 0, 255]
      fg_c.r, fg_c.g, fg_c.b, fg_c.a = [0, 0, 255, 255]
    end
    
    # @display.colors.pixel CP::Vec2.new(50,50) do |bg_c, fg_c|
    #   bg_c.r, bg_c.g, bg_c.b, bg_c.a = [255, 0, 0, 255]
    #   fg_c.r, fg_c.g, fg_c.b, fg_c.a = [0, 0, 255, 255]
    # end
    
    
    
    
    # CP::BB
    # l,b,r,t
    bb = CP::BB.new(0,0, 18,9)
    
    @display.colors.each_with_index do |bg_c, fg_c, pos|
      if bb.contain_vect? pos
        bg_c.r, bg_c.g, bg_c.b, bg_c.a = [0, 0, 0, 255]
        fg_c.r, fg_c.g, fg_c.b, fg_c.a = [255, 255, 255, 255]
      end
    end
    
    (0..(bb.t)).each do |i|
      @display.print_string(CP::Vec2.new(0, i), " "*(bb.r+1))
    end
    
    
  end
  
  def update
    # super()
    
    @input_handler.update
    
    
    
    # p @cpp_val["midiMessageQueue"]
    
    delta = @midi_msg_memory.delta_from_sample(@cpp_val["midiMessageQueue"])
    # print "diff size: #{diff.size}  "; p diff.map{|x| x.to_s }
    
    
    
    
    
    delta.each do |midi_msg|
      # case midi_msg[0]
      # when 0x90 # note on
      #   @cpp_ptr["midiOut"].sendNoteOn( 3, midi_msg.pitch+4, midi_msg.velocity)
      #   @cpp_ptr["midiOut"].sendNoteOn( 3, midi_msg.pitch+7, midi_msg.velocity)
      #   # puts "ON: #{midi_msg.to_s}"
        
      # when 0x80 # note off
      #   @cpp_ptr["midiOut"].sendNoteOff(3, midi_msg.pitch+4, midi_msg.velocity)
      #   @cpp_ptr["midiOut"].sendNoteOff(3, midi_msg.pitch+7, midi_msg.velocity)
      #   # puts "OFF: #{midi_msg.to_s}"
        
      # end
      
      if @looper_mode == :record
        @looper << midi_msg
      end
    end
    
    
    
    
    
    
    if @looper_mode == :playback
      @looper_fiber ||= Fiber.new do 
        @looper_acc = 0
        @looper_i = 0
        
        now = RubyOF::Utils.ofGetElapsedTimeMillis()
        @looper_start = now
        
        
        msg = @looper[@looper_i]
        case msg[0]
        when 0x90 # note on
          @cpp_ptr["midiOut"].sendNoteOn( 3, msg.pitch, msg.velocity)
        when 0x80 # note off
          @cpp_ptr["midiOut"].sendNoteOff(3, msg.pitch, msg.velocity)
        end
        
        
        loop do
          @looper_i += 1
          @looper_i = 0 if @looper_i >= @looper.length
          
          msg = @looper[@looper_i]
          @looper_acc += msg.deltatime
          
          now = RubyOF::Utils.ofGetElapsedTimeMillis()
          dt = now - @looper_start
          
          until dt >= @looper_acc
            Fiber.yield
            
            now = RubyOF::Utils.ofGetElapsedTimeMillis()
            dt = now - @looper_start
          end
          
          case msg[0]
          when 0x90 # note on
            @cpp_ptr["midiOut"].sendNoteOn( 3, msg.pitch, msg.velocity)
          when 0x80 # note off
            @cpp_ptr["midiOut"].sendNoteOff(3, msg.pitch, msg.velocity)
          end
          
          
          
          
          # # after final note, wait until the end of the loop clip
          # if @looper_i == @looper.length-1
          #   loop_length = @looper_end - @looper_start
          #   final_acc = loop_length - @looper_acc
            
          #   now = RubyOF::Utils.ofGetElapsedTimeMillis()
          #   dt = now - @looper_start
            
          #   until dt >= final_acc
          #     Fiber.yield
              
          #     now = RubyOF::Utils.ofGetElapsedTimeMillis()
          #     dt = now - @looper_start
          #   end
          # end
          
          
        end
        
        
      end
      
      
      @looper_fiber.resume()
    end
    
    
    
    
    
    
    
    
    
    # write all messages in buffer to the character display
    # TODO: need live coding ASAP for this
    
    # TODO: clear an entire zone of characters with "F" because if code crashes (in live load mode) in this section, weird glitches could happen
    # (or just let them happen - it could be pretty!)
    
    # TODO: need a way to shift an existing block of text in the display buffer
    
    
    
    @cpp_val["midiMessageQueue"].each_with_index do |midi_msg, i|
      
      
      @display.print_string(CP::Vec2.new(0,i), midi_msg[0].to_s(16))
      
      @display.print_string(CP::Vec2.new(3,i), midi_msg[1].to_s(16))
      
      @display.print_string(CP::Vec2.new(6,i), midi_msg[2].to_s(16))
      
      
      midi_dt = midi_msg.deltatime
        max_display_num = 99999.999
      midi_dt = [max_display_num, midi_dt].min
      
      msg = ("%.3f" % midi_dt).rjust(max_display_num.to_s.length)
      @display.print_string(CP::Vec2.new(10,i), msg)
      
      
    end
    
    
    @display.print_string(CP::Vec2.new(46,0), "r  g  b  a ")
    .each do |pos|
      @display.colors.pixel pos do |bg_c, fg_c|
        bg_c.r, bg_c.g, bg_c.b, bg_c.a = [0,0,0,255]
        fg_c.r, fg_c.g, fg_c.b, fg_c.a = ([(0.5*255).to_i]*3 + [255])
      end
    end
    @cpp_ptr["colorPicker_color"].tap do |c|
      output_string = [c.r,c.g,c.b,c.a].map{|x| x.to_s(16) }.join(",")
      
      @display.print_string(CP::Vec2.new(46,1), output_string)
      .each do |pos|
        @display.colors.pixel pos do |bg_c, fg_c|
          bg_c.r, bg_c.g, bg_c.b, bg_c.a = [c.r, c.g, c.b, c.a]
          fg_c.r, fg_c.g, fg_c.b, fg_c.a = ([(0.5*255).to_i]*3 + [255])
        end
      end
    end
    
    
    
    
    @hbar ||= {
      '8/8' => '█',
      '7/8' => '▉',
      '6/8' => '▊',
      '5/8' => '▋',
      '4/8' => '▌',
      '3/8' => '▍',
      '2/8' => '▎',
      '1/8' => '▏'
    }
    
    @vbar ||= {
      '1/8' => '▁',
      '2/8' => '▂',
      '3/8' => '▃',
      '4/8' => '▄',
      '5/8' => '▅',
      '6/8' => '▆',
      '7/8' => '▇',
      '8/8' => '█'
    }
    
    

    
    lilac       = [0xf6, 0xbf, 0xff, 0xff]
    pale_blue   = [0xa2, 0xf5, 0xff, 0xff]
    pale_green  = [0x93, 0xff, 0xbb, 0xff]
    pale_yellow = [0xff, 0xfc, 0xac, 0xff]
    
    
    
    count = 16 # 128 midi notes, so 16 chars of 8 increments each will cover it
    bg_color = ([(0.5*255).to_i]*3 + [255])
    fg_color = lilac
    
    @display.print_string(CP::Vec2.new(27,14+0), 'x'*count)
    .each do |pos|
      @display.colors.pixel pos+CP::Vec2.new(0,0) do |bg_c, fg_c|
        bg_c.r, bg_c.g, bg_c.b, bg_c.a = bg_color
        fg_c.r, fg_c.g, fg_c.b, fg_c.a = fg_color
      end
      
      @display.colors.pixel pos+CP::Vec2.new(0,1) do |bg_c, fg_c|
        bg_c.r, bg_c.g, bg_c.b, bg_c.a = bg_color
        fg_c.r, fg_c.g, fg_c.b, fg_c.a = fg_color
      end
    end
    
    @display.print_string(
      CP::Vec2.new(27,14+1), @hbar['8/8']*(count-1)+@hbar['1/8']
    )
    
    
    # TODO: improve interface - CharMappedDisplay#each_index and CharMappedDisplay#colors.pixel (and similar) need new names
    
      # The name #each_index is confusing, because the block var is a vec2 (2d "index") not an int (1D linear index)
      
      # The name #pixel is confusing because it refers to the backend data store, which is not very important. but the question is: what you do call one element of a discrete mesh that holds color data? isn't that what a pixel is? (I mean like, in the abstract sense)
    
    # hmmm drawing a vertical bar is harder, because there's no Enumerators in this direction...
    count = 4
    anchor = CP::Vec2.new(20,15) # bottom left position
    bg_color = ([(0.5*255).to_i]*3 + [255])
    fg_color = pale_yellow
    
    @display.each_index
    .select{   |pos| pos.x == anchor.x+0  }
    .select{   |pos| ((anchor.y-(count-1))..(anchor.y)).include? pos.y }
    .sort_by{  |pos| -pos.y } # y+ down, so top position has the lowest y value
    .each_with_index do |pos, i|
      @display.print_string(pos + CP::Vec2.new(0,0), 'x')
      
      if i == 3
        @display.print_string(pos + CP::Vec2.new(1,0), @vbar['3/8'])
      else
        @display.print_string(pos + CP::Vec2.new(1,0), @vbar['8/8'])
      end
      
      
      @display.colors.pixel pos + CP::Vec2.new(1,0) do |bg_c, fg_c|
        bg_c.r, bg_c.g, bg_c.b, bg_c.a = bg_color
        fg_c.r, fg_c.g, fg_c.b, fg_c.a = fg_color
      end
    end
    
    
    
    
  end
  
  
  include RubyOF::Graphics
  def draw
    # super()
    ofBackground(200, 200, 200, 255)
    
    
    if @first_draw
      # screen_size = read_screen_size("Screen 0")
      # screen_w, screen_h = screen_size["current"]
      # puts "screen size: #{[screen_w, screen_h].inspect}"
      
      puts "---> callback from ruby"
      @cpp_ptr["midiOut"].listOutPorts()
      puts "<--- callback end"
      
      
      @first_draw = false
    end
    
    
    
    # NOTE: need live coding before I can fiddle with graphics code
    # don't need time scrubbing quite yet, just need to be able to change parameters at runtime
    
    @origin ||= CP::Vec2.new(370,500)
    # line_height = 38
    
    
    # screen_print(font: @fonts[:monospace], color: @text_fg_color,
    #              string: "hello world!",
    #              position: origin+CP::Vec2.new(0,line_height*0))
    
    # ^ if you bind the font texture here before drawing the rectangular mesh below, then the mesh will be invisible. not sure why. likely some bug is happening with textures?
    
    
    
    
    
    # @display.reload_shader
    
    z = 5
    @display.draw(@origin, z)
    
    
    
    # RubyOF::CPP_Callbacks.render_material_editor(
    #   @cpp_ptr["materialEditor_mesh"],
    #   @cpp_ptr["materialEditor_shader"], "material_editor",
      
    #   @fonts[:monospace].font_texture,
    #   @cpp_ptr["display_fg_texture"], # <-- no longer available
      
    #   20, 500, 300, 300 # x,y,w,h
    # )
    
  end
  
  def setup_character_mesh
    return [@char_grid_width, @char_grid_height]
  end
  
  
  def screen_print(font:, string:, position:, z:1, color: @text_fg_color)
    
      font.font_texture.bind
    
      ofPushMatrix()
      ofPushStyle()
    begin
      ofTranslate(position.x, position.y, z)
      
      ofSetColor(color)
      
      # ofLoadViewMatrix(const glm::mat4 & m) # <- bound in Graphics.cpp
      
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
  
  
  # delegate inputs to input handler
  INPUT_EVENTS = 
  [
    # :key_pressed,
    # :key_released,
    # :mouse_moved,
    # :mouse_pressed,
    # :mouse_dragged,
    :mouse_released,
    :mouse_scrolled,
  ]
  INPUT_EVENTS.each do |sym|
    define_method sym do |*args|
      # super(*args)
      # ^ Calls Ruby-defined callback functions, not the C++ ones.
      #   Useful for baseline debugging, but not otherwise necessary
      
      # @input_queue << [sym, args]
    end
  end
  
  def key_pressed(key)
    @input_handler.key_pressed(key)
  end
  
  def key_released(key)
    @input_handler.key_released(key)
  end
  
  
  
  # 
  # mouse prints position in character grid to STDOUT
  # 
  
  def mouse_moved(x,y)
    p "mouse position: #{[x,y]}.inspect"
  end
  
  def mouse_pressed(x,y, button)
    # p [:pressed, x,y, button]
    
    offset = CP::Vec2.new(0,10) # probably related to font ascender height
    
    out = ( CP::Vec2.new(x,y) - @origin - offset )
    
    out.x = (out.x / @display.char_width_pxs).to_i
    out.y = (out.y / @display.char_height_pxs).to_i
    
    puts out
  end
  
  def mouse_dragged(x,y, button)
    # p [:dragged, x,y, button]
    
    offset = CP::Vec2.new(0,10)
    
    out = ( CP::Vec2.new(x,y) - @origin - offset )
    
    out.x = (out.x / @display.char_width_pxs).to_i
    out.y = (out.y / @display.char_height_pxs).to_i
    
    puts out
  end
  
  def mouse_released(x,y, button)
    # p [:released, x,y, button]
  end
  
  
  
  def on_exit
    super()
    
    
    # --- Save data
    pt = self.get_window_position()
    dump_yaml [pt.x, pt.y, self.width, self.height] => @window_geometry_file
    
    # --- Clear Ruby-level memory
    GC.start
    
    puts "FINISHED!"
    
  end
  
  
  
  
  
  
  # this is for drag-and-drop, not for mouse dragging
  def drag_event(files, position)
    p [files, position]
    
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
  
  
  # direct access to data used on the C++ side
  def recieve_cpp_pointer(name, data)
    @cpp_ptr[name] = data
  end
  
  # copy of the data from the C++ side
  def recieve_cpp_value(name, data)
    @cpp_val[name] = data
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
