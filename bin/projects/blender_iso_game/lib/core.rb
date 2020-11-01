
# stores the main logic and data of the program

require 'json' # easiest way to transfer data between Python and Ruby

require 'open3'

require 'io/wait'

# stuff to load just once
require LIB_DIR/'input_handler.rb'
require LIB_DIR/'sequence_memory.rb'
require LIB_DIR/'scheduler.rb'


# stuff to live load ('load' allows for reloading stuff)
load LIB_DIR/'char_mapped_display.rb'
load LIB_DIR/'looper_pedal.rb'

# class definition


# SPIKE_PROFILER_ON = true
# SPIKE_PROFILER_ON = false



# convert time in milliseconds to standard time units (microseconds)
def msec(time)
  (time * 1000).to_i
end

# convert time in microseconds to standard time units (microseconds)
def usec(time)
  (time).to_i
end


class BlenderCube
  attr_reader :mesh, :node
  
  def initialize
    @mesh = RubyOF::Mesh.new
    @node = RubyOF::Node.new
  end
  
  def position
    return @node.position
  end
  
  def position=(pos)
    @node.position = pos
  end
  
  
  
  def generate_mesh
    
    @mesh = RubyOF::Mesh.new
    # p mesh.methods
    @mesh.setMode(:OF_PRIMITIVE_TRIANGLES)
    # (ccw from bottom right)
    # (top layer)
    @mesh.addVertex(GLM::Vec3.new( 1, -1,  1))
    @mesh.addVertex(GLM::Vec3.new( 1,  1,  1))
    @mesh.addVertex(GLM::Vec3.new(-1,  1,  1))
    @mesh.addVertex(GLM::Vec3.new(-1, -1,  1))
    # (bottom layer)
    @mesh.addVertex(GLM::Vec3.new( 1, -1, -1))
    @mesh.addVertex(GLM::Vec3.new( 1,  1, -1))
    @mesh.addVertex(GLM::Vec3.new(-1,  1, -1))
    @mesh.addVertex(GLM::Vec3.new(-1, -1, -1))
    
    
    # raise
    
    # TODO: pay attention to winding
    # (need to figure out axes first)
    
    # right
    @mesh.addIndex(1-1+4*0)
    @mesh.addIndex(2-1+4*0)
    @mesh.addIndex(2-1+4*1)
    
    @mesh.addIndex(1-1+4*0)
    @mesh.addIndex(1-1+4*1)
    @mesh.addIndex(2-1+4*1)
    
    # left
    @mesh.addIndex(3-1+4*0)
    @mesh.addIndex(3-1+4*1)
    @mesh.addIndex(4-1+4*1)
    
    @mesh.addIndex(3-1+4*0)
    @mesh.addIndex(4-1+4*0)
    @mesh.addIndex(4-1+4*1)
    
    # top
    @mesh.addIndex(1-1+4*0)
    @mesh.addIndex(2-1+4*0)
    @mesh.addIndex(3-1+4*0)
    
    @mesh.addIndex(3-1+4*0)
    @mesh.addIndex(4-1+4*0)
    @mesh.addIndex(1-1+4*0)
    
    # bottom
    @mesh.addIndex(1-1+4*1)
    @mesh.addIndex(2-1+4*1)
    @mesh.addIndex(3-1+4*1)
    
    @mesh.addIndex(3-1+4*1)
    @mesh.addIndex(4-1+4*1)
    @mesh.addIndex(1-1+4*1)
    
    # front
    @mesh.addIndex(4-1+4*1)
    @mesh.addIndex(1-1+4*1)
    @mesh.addIndex(1-1+4*0)
    
    @mesh.addIndex(4-1+4*1)
    @mesh.addIndex(1-1+4*0)
    @mesh.addIndex(4-1+4*0)
    
    # back
    @mesh.addIndex(3-1+4*1)
    @mesh.addIndex(2-1+4*1)
    @mesh.addIndex(2-1+4*0)
    
    @mesh.addIndex(2-1+4*0)
    @mesh.addIndex(3-1+4*0)
    @mesh.addIndex(3-1+4*1)
    
    
  end
end



class Core
  include HelperFunctions
  
  def initialize(window)
    @w = window
  end
  
  def setup
    puts "core: setup"
    
    ofBackground(200, 200, 200, 255)
    ofEnableBlendMode(:alpha)
    
    
    @draw_durations = Array.new # stores profiler data for #draw
    
    
    @first_update = true
    @mouse = CP::Vec2.new(0,0)
    
    
    @midi_msg_memory = SequenceMemory.new
    @input_handler = InputHandler.new
    
    
    
    @fonts = Hash.new
    
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
    
    
    @fonts[:monospace] = 
      RubyOF::TrueTypeFont.dsl_load do |x|
        x.path = "DejaVu Sans Mono"
        x.size = 24
        #  6 is ok = 9.3125    5/16
        #  9 is ok = 13.96875  33/64
        # 12 is ok = 18.625    5/8
        # 15 is ok = 23.28125  1/64
        # 18 is ok = 27.9375   7/16
        # 24 is ok = 37.25     1/4
        # 33 is ok = 51.21875  7/32
        # 36 is ok = 55.875    7/8
        # 42 is ok = 65.1875   3/16
        # 45 is ok = 69.84375  33/64
        # 48 is ok = 74.5               24*2
        # 96 is ok = 149.0 (EXACTLY)    24*4
        
        
        x.add_alphabet :Latin
        x.add_unicode_range :BlockElement
      end
    
    
    
    @colors = {
      :lilac       => RubyOF::Color.hex_alpha( 0xf6bfff, 0xff ),
      :pale_blue   => RubyOF::Color.hex_alpha( 0xa2f5ff, 0xff ),
      :pale_green  => RubyOF::Color.hex_alpha( 0x93ffbb, 0xff ),
      :pale_yellow => RubyOF::Color.hex_alpha( 0xfffcac, 0xff ),
    }
    
    
    
    
    
    @cube = BlenderCube.new
    
    @camera = RubyOF::Camera.new
    @light  = RubyOF::Light.new
    
    
    
    @camera_settings_file = PROJECT_DIR/'bin'/'data'/'viewport_camera.yaml'
    if @camera_settings_file.exist?
      camera_data = YAML.load_file @camera_settings_file
      parse_blender_data(camera_data)
      @camera_changed = false
    end
    
    
    
    
    # 
    # Open FIFO in main thread then pass to Thread using function closure.
    # This prevents weird race conditions.
    # 
    # Consider this timing diagram:
    #   main thread         @msg_thread
    #   -----------         -----------
    #   setup               
    #                       File.mkfifo(fifo_path)
    #                       
    #   update (ERROR)
    #                       f_r = File.open(fifo_path, "r+")
    #                       
    #                       ensure: f_r#close
    #                       ensure: FileUtils.rm(fifo_path)
    # 
    # ^ When the error happens in update
    #   f_r has not yet been initialized (f_r == nil)
    #   but the ensure block of @msg_thread will try close f_r.
    #   This results in an exception, 
    #   which prevents the FIFO from being properly deleted.
    #   This will then cause an error when the program is restarted / reloaded
    #   as a FIFO can not be created where one already exists.
    
    @fifo_dir = PROJECT_DIR/'bin'/'run'
    @fifo_name = 'blender_comm'
    
      fifo_path = @fifo_dir/@fifo_name
      
      File.mkfifo(fifo_path)
      puts "fifo created @ #{fifo_path}"
      
      f_r = File.open(fifo_path, "r+")
    
    @msg_queue = Queue.new
    @msg_thread = Thread.new do
      begin
        loop do
          data = f_r.gets # blocking IO
          @msg_queue << data
        end
      ensure
        p f_r
        p fifo_path
        
        f_r.close
        FileUtils.rm(fifo_path)
        puts "fifo closed"
      end
    end
  end
  
  # run when exception is detected
  def on_crash
    puts "core: on_crash"
    @crash_detected = true
    
    
    self.ensure()
  end
  
  # run on normal exit, before exiting program
  def on_exit
    puts "core: on exit"
    
    unless @crash_detected
      self.ensure()
    end
    
      
    # puts @draw_durations.join("\t")
    if RB_SPIKE_PROFILER.enabled?
      RB_SPIKE_PROFILER.disable
    end
    
    if @camera_changed
      # camera_pos = @camera.position
      # camera_rot = @camera.orientation
      
      # camera_data = [
      #     {
      #     'name' => 'viewport_camera',
      #     'position' => [
      #       'Vec3',
      #       camera_pos.x, camera_pos.y, camera_pos.z
      #     ],
      #     'rotation' => [
      #       'Quat',
      #       camera_rot.w, camera_rot.x, camera_rot.y, camera_rot.z
      #     ]
      #   }
      # ]
      # dump_yaml camera_data => @camera_settings_file
    end
    
  end
  
  
  def on_reload
    unless @crash_detected
      self.ensure()
    end
    
    puts "core: on reload"
    @crash_detected = false
    
    @shader_files = nil
    @shaderIsCorrect = nil
    
    @update_scheduler = nil
    
    setup()
  end
  
  # always run on exit, with or without exception
  # and also trigger when code is reloaded
  # BUT make sure to only run this once per pathway
  # (ex1 if triggered on exception flow, don't trigger again on exit)
  # (ex2 if you have a bad reload and then manually exit, only call ensure 1x)
  def ensure
     puts "core: ensure"
    @msg_thread.kill.join
    sleep(0.1) # just a little bit extra time to make sure the FIFO is deleted
  end
  
  def parse_blender_data(data_list)
    data_list.each do |obj|
      case obj['type']
      when 'viewport_region'
        w = obj['width']
        h = obj['height']
        @w.set_window_shape(w,h)
        
        @camera.setAspectRatio(w.to_f/h.to_f)
        
        
      when 'viewport_camera'
        puts "update viewport"
        
        pos  = GLM::Vec3.new(*(obj['position'][1..3]))
        quat = GLM::Quat.new(*(obj['rotation'][1..4]))
        
        @camera.position = pos
        @camera.orientation = quat
        
        
        @camera_changed = true
        
        mat = obj['window_matrix'].last(16)
        p mat
        
        fx = ->(arr, x,y){
          return arr[x+4*y]
        }
        
        @camera_transform = 
          GLM::Mat4.new(
            GLM::Vec4.new(0,1,2,3),
            GLM::Vec4.new(4,5,6,7),
            GLM::Vec4.new(8,9,10,11),
            GLM::Vec4.new(12,13,14,15),
          )
        # p obj['aspect_ratio'][1]
        @camera.setAspectRatio(obj['aspect_ratio'][1])
        # puts "force aspect ratio flag: #{@camera.forceAspectRatio?}"
        
        # p obj['view_perspective']
        case obj['view_perspective']
        when 'PERSP'
          @camera.disableOrtho()
          @cam_scale = nil
          
          @camera.setFov(obj['fov'][1])
          
        when 'ORTHO'
          @camera.enableOrtho()
          @cam_scale = 30
          # TODO: scale needs to change as camera is updated
          # TODO: scale zooms as expected, but also effects pan rate (bad)
          
          obj['perspective_matrix'].last(16)
          
        when 'CAMERA'
          
          
        end
      when 'MESH'
        pos  = GLM::Vec3.new(*(obj['position'][1..3]))
        @cube.position = pos
      end
    end
  end
  
  
  # use a structure where Fiber does not need to be regenerated on reload
  def update
    @update_scheduler ||= Scheduler.new(self, :on_update, msec(16-4))
    
    # puts ">>>>>>>> update #{RubyOF::Utils.ofGetElapsedTimeMicros}"
    @start_time = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # puts "update thread: #{Thread.current.object_id}" 
    
    # if SPIKE_PROFILER_ON
    #   RB_SPIKE_PROFILER.enable
    # end
    
    # puts "--> start update"
    signal = @update_scheduler.resume
    # puts signal
    # puts "<-- end update"
    
    # if SPIKE_PROFILER_ON
    #   RB_SPIKE_PROFILER.disable
    #   puts "\n"*7
    # end
    
  end
  
  # methods #update and #draw are called by the C++ render loop
  # Their only job now at the Ruby level is to set up Fibers
  # which call the true render logic. This structure is necessary
  # to allow for live loading - if the update / draw logic
  # is directly inside the Fiber, there's no good way to reload it
  # when the file reloads.
  def on_update(scheduler)
    scheduler.section name: "shaders", budget: msec(1.5)
      # puts "shaders" if Scheduler::DEBUG
      
      # # liveGLSL.foo "char_display" do |path_to_shader|
      #   # @display.reload_shader
      # # end
      
      
      # # prototype possible smarter live-loading system for GLSL shaders
      
      
      # bg_shader_name = "char_display_bg"
      # fg_shader_name = "char_display"
      
      # @shader_files ||= [
      #   PROJECT_DIR/"bin/data/#{bg_shader_name}.vert",
      #   PROJECT_DIR/"bin/data/#{bg_shader_name}.frag",
      #   PROJECT_DIR/"bin/data/#{fg_shader_name}.vert",
      #   PROJECT_DIR/"bin/data/#{fg_shader_name}.frag"
      # ]
      
      # @shaderIsCorrect ||= nil # NOTE: value manually reset in #on_reload
      
      # # load shader if it has never been loaded before, or if the files have been updated
      # if @shaderIsCorrect.nil? || @shader_files.any?{|f| @shader_timestamp.nil? or f.mtime > @shader_timestamp }
      #   loaded = @display.load_shaders(bg_shader_name, fg_shader_name)
        
        
        
      #   puts "load code: #{loaded}"
      #   # ^ apparently the boolean is still true when the shader is loaded with an error???
        
      #   puts "loaded? : #{@display.fg_shader_loaded?}"
      #   # ^ this doesn't work either
        
      #   # puts "loaded? : #{@display.bg_shader_loaded?}"
        
        
        
      #   # This is a long-standing issue, open since 2015:
        
      #   # https://forum.openframeworks.cc/t/identifying-when-ofshader-hasnt-linked/30626
      #   # https://github.com/openframeworks/openFrameworks/pull/3734
        
      #   # (the Ruby code I have here is still better than the naieve code, because it prevents errors from flooding the terminal, but it would be great to detect if the shader is actually correct or not)
        
        
      #   if loaded
      #     case @shaderIsCorrect
      #     when true
      #       # good -> good
      #       puts "GLSL: still good"
      #     when false
      #       # bad -> good
      #       puts "GLSL: fixed!"
      #     when nil
      #       # nothing -> good
      #       puts "GLSL: shader loaded"
      #     end
          
      #     @shaderIsCorrect = true
      #   else
      #     case @shaderIsCorrect
      #     when true
      #       # good -> bad
      #       puts "GLSL: something broke"
      #     when false
      #       # bad -> bad
      #       puts "GLSL: still broken..."
      #     when nil
      #       # nothing -> bad
      #       puts "GLSL: could not load shader"
      #     end
          
      #     @shaderIsCorrect = false;
      #   end
          
        
      #   @shader_timestamp = Time.now
      # end
    
    
    if @debugging
      
      # scheduler.section name: "debug setup", budget: msec(0.5)
      # @debug_mode ||= DebugDisplayClipping.new
      
      # scheduler.section name: "debug run", budget: msec(1.0)
      
      # @debug_mode.update
      
      
      scheduler.section name: "profiler init", budget: msec(1)
      puts "profiler" if Scheduler::DEBUG
      
      @main_modes[1] ||= ProfilerState.new(@update_scheduler, @draw_durations)
      
      
      scheduler.section name: "profiler run", budget: msec(4)
      
      @main_modes[1].update(@whole_iter_dt)
      
    end
    
    scheduler.section name: "cube ", budget: msec(1.0)
      # puts "set cube mesh"
    
    
    scheduler.section name: "end", budget: msec(0.1)
    # ^ this section does literally nothing,
    #   but if I set the budget to 1000 us, it can take as much as 925 us
    #   with budget at 100 us, it seems to cap at 162 um
    #   thus, it appears that the max time used depends on the budget given
    #   why is that?
    #   what about the scheduling algorithm produces this behavior?
    # 
    # nope, just saw a max of 826 us with a budget of 0.1 us
    # (not sure when I saved - have to try this again...)
    # 
    # currently seeing max of 697 us with a budget of 100 us
    # I think that the time consumed can go over budget, even when total budget < 16.6 ms - which is what I expected the code to do
    
    # puts "end"
    
    

    
  end
  
  
  
  
  
  def draw
    # puts ">>>>>>>> draw #{RubyOF::Utils.ofGetElapsedTimeMicros}"
    
    # puts "draw thread:   #{Thread.current.object_id}" 
    
    # draw_start = Time.now
    draw_start = RubyOF::Utils.ofGetElapsedTimeMicros
    
      on_draw()
    
    # draw_end = Time.now
    draw_end = RubyOF::Utils.ofGetElapsedTimeMicros
    dt = draw_end - draw_start
    puts "draw duration: #{dt}" if Scheduler::DEBUG
    
    
    
    draw_duration_history_len = 100
    
    
    @draw_durations << dt
    # puts "draw duration: #{dt}"
    
    if @draw_durations.length > draw_duration_history_len
      d_len = @draw_durations.length - draw_duration_history_len
      @draw_durations.shift(d_len)
    end
    
    
    
    
    if @start_time
      end_time = RubyOF::Utils.ofGetElapsedTimeMicros
      @whole_iter_dt = end_time - @start_time
    end
  end
  
  
  
  include RubyOF::Graphics
  def on_draw
    
    
    # 
    # puts "draw cube"
    # File.open(@fifo_dir/@fifo_name, "r") do
      
    # end
    
    
    # (may need to open the fifo and write something to it, so we get an EOF descriptor that will be useful for implementing non-blocking IO)
    
    # puts "<---"
    
    
    
    
    
    c = RubyOF::Color.hex_alpha( 0xf6bfff, 0xff )
    
    
    
    # @camera.setPosition(GLM::Vec3.new(50, 50, 0))
    # @camera.lookAt(GLM::Vec3.new(0, 0, 0))
    
    # @camera.setFov(39.6)
    @camera.setNearClip(0.1)
    @camera.setFarClip(1000)
    
    # @camera.setAspectRatio()
    
    
    
    @light.setPointLight()
    @light.position = GLM::Vec3.new(4, 1, 6)
    
    
    
    @cube.generate_mesh
    
    # f.close
    # puts "---"
    
    
    
    
    max_reads = 5
    [max_reads, @msg_queue.length].min.times do
      data = @msg_queue.pop
      
      json_obj = JSON.parse(data)
      # p json_obj
      
      
      # TODO: need to send over type info instead of just the object name, but this works for now
      
      parse_blender_data(json_obj)
      
    end
    
    
    
    @camera.begin
    # ofPushMatrix();
    # unless @camera_transform.nil?
    #   # puts "applying camera transform"
    #   # ofLoadMatrix(@camera_transform)
    #   ofMultMatrix(@camera_transform)
    # end
    
    # puts @camera.getProjectionMatrix
    
    # if @camera.ortho?
    # if @cam_scale # Camera#ortho? doesn't work right now, idk why
    #   ofScale(@cam_scale, @cam_scale, @cam_scale)
    #   puts "scaling"
      
      
    #   # https://github.com/roymacdonald/ofxInfiniteCanvas/blob/master/src/ofxInfiniteCanvas.cpp
    #   # translation = clicTranslation - clicPoint*(scale - clicScale);
      
      
    #   # oh wait, need to use a different way to compute viewport camera position when in ortho mode. that should feed into this.
    # end
    
      @light.enable
        
        @cube.node.transformGL()
      # ofScale(10000,10000,10000)
      
        
        @cube.mesh.draw()
        @cube.node.restoreTransformGL()
      
      @light.disable
    
    @camera.end
    # ofPopMatrix();
    
    
    
    # 
    # render text display
    # 
    
    # @display.draw()
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
    # p "mouse position: #{[x,y]}.inspect"
  end
  
  def mouse_pressed(x,y, button)
    # p [:pressed, x,y, button]
    
  end
  
  def mouse_dragged(x,y, button)
    # p [:dragged, x,y, button]
    # puts @mouse
  end
  
  def mouse_released(x,y, button)
    # p [:released, x,y, button]
  end
  
  
  
  # this is for drag-and-drop, not for mouse dragging
  def drag_event(files, position)
    p [files, position]
    
  end
  
  
  
  
  
  private
  
  
  def screen_print(font:, string:, position:, color: )
    
      font.font_texture.bind
    
      ofPushMatrix()
      ofPushStyle()
    begin
      ofTranslate(position.x, position.y, 0)
      
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
  
  def read_fifo(fifo_path)
    # f = File.open(@fifo_dir/@fifo_name, "r")
    
    # data = f.gets
    # unless data.nil
    #   puts data
    # end
    
    
    
    # 
    # blocking read
    # (can read data)
    # 
    
    # f_r = File.open(@fifo_dir/@fifo_name, "r+")
    # data = f_r.gets
    # p data
    
    
    
    # 
    # nonblocking read
    # https://stackoverflow.com/questions/9803019/ruby-non-blocking-line-read
    # (doesn't work)
    # 
    
    # buffer = ""
    # begin
    #   f_r = File.open(@fifo_dir/@fifo_name, "r+")
      
    #   while buffer[-1] != "\n"
    #     buffer << f_r.read_nonblock(1)
    #   end
      
    #   p buffer
    # rescue IO::WaitReadable => e
    #   if buffer.empty?
    #     puts "error" 
    #     puts e
    #   else
    #     p buffer
    #   end
    # ensure
    #   f_r.close
    # end
    
    
    
    # 
    # nonblocking read,
    # attempt 2
    # https://www.ruby-forum.com/t/nonblocking-io-read/74621/7
    # https://stackoverflow.com/questions/1779347/using-rubys-ready-io-method-with-gets-puts-etc
    # https://stackoverflow.com/questions/930989/is-there-a-simple-method-for-checking-whether-a-ruby-io-instance-will-block-on-r
    # 
    
    # f_r = File.open(@fifo_dir/@fifo_name, "r+")
    # puts f_r.nread
    # if f_r.ready?
      # p f_r.gets
    # end
    # f_r.close
    
    
    
    # 
    # nonblocking read
    # attempt 3
    # building on attempt 2, but use IO#wait instead of IO#ready?
    # 
    data = nil
    
    f_r = File.open(fifo_path, "r+")
    flag = f_r.wait(0.0001) # timeout in seconds
    if flag
      data = f_r.gets
    end
    
    f_r.close
    
    return data
  end
  
  
end





CUSTOM_PROF = TracePoint.new(:c_call) do |tp|
  # event = tp.event.to_s.sub(/(.+(call|return))/, '\2').rjust(6, " ")
  
  # inspect_this = 
  #   case tp.self
  #   when CharMappedDisplay
  #     "CharMappedDisplay<>"
  #   when CharMappedDisplay::ColorHelper
  #     "CharMappedDisplay::ColorHelper<>"
  #   else
  #     tp.self.inspect
  #   end
  
  # message = "#{event} of #{tp.defined_class}##{tp.callee_id} from #{tp.path.gsub(/#{GEM_ROOT}/, "[GEM_ROOT]")}:#{tp.lineno}"
  
  # # if you call `return` on any non-return events, it'll raise error
  # if tp.event == :return || tp.event == :c_return
  #   inspect_return = 
  #     case tp.return_value
  #     when CharMappedDisplay
  #       "CharMappedDisplay<>"
  #     when CharMappedDisplay::ColorHelper
  #       "CharMappedDisplay::ColorHelper<>"
  #     else
  #       tp.return_value.inspect
  #     end
    
  #   message += " => #{inspect_return}" 
  # end
  # puts(message)
  
  
  printf "%8s %s:%-2d %10s %8s\n", tp.event, tp.path.split("/").last, tp.lineno, tp.callee_id, tp.defined_class
end



def custom_profiler() # &block
  CUSTOM_PROF.enable do
    yield
  end
end


  
TRACER = TracePoint.new(:call, :return, :c_return) do |tp|
  # event = tp.event.to_s.sub(/(.+(call|return))/, '\2').rjust(6, " ")
  
  # inspect_this = 
  #   case tp.self
  #   when CharMappedDisplay
  #     "CharMappedDisplay<>"
  #   when CharMappedDisplay::ColorHelper
  #     "CharMappedDisplay::ColorHelper<>"
  #   else
  #     tp.self.inspect
  #   end
  
  # message = "#{event} of #{tp.defined_class}##{tp.callee_id} from #{tp.path.gsub(/#{GEM_ROOT}/, "[GEM_ROOT]")}:#{tp.lineno}"
  
  # # if you call `return` on any non-return events, it'll raise error
  # if tp.event == :return || tp.event == :c_return
  #   inspect_return = 
  #     case tp.return_value
  #     when CharMappedDisplay
  #       "CharMappedDisplay<>"
  #     when CharMappedDisplay::ColorHelper
  #       "CharMappedDisplay::ColorHelper<>"
  #     else
  #       tp.return_value.inspect
  #     end
    
  #   message += " => #{inspect_return}" 
  # end
  # puts(message)
  
  
  printf "%8s %s:%-2d %10s %8s\n", tp.event, tp.path.split("/").last, tp.lineno, tp.callee_id, tp.defined_class

  
end

def trace() # &block
  TRACER.enable do
    yield
  end
end


require 'ruby-prof'
def run_profiler() # &block
  # PROFILER.enable do
  #   yield
  # end
  
  profile = RubyProf.profile do
    yield
  end
  
  printer = RubyProf::FlatPrinter.new(profile)
  
  printer.print(STDOUT, :min_percent => 2)
end

# https://gist.github.com/lpar/1032297#file-timeout-rb-L37
BUFFER_SIZE = 30
def run_with_timeout(command, timeout, tick)
  output = ''
  begin
    # Start task in another thread, which spawns a process
    stdin, stderrout, thread = Open3.popen2e(command)
    # Get the pid of the spawned process
    pid = thread[:pid]
    start = Time.now

    while (Time.now - start) < timeout and thread.alive?
      # Wait up to `tick` seconds for output/error data
      Kernel.select([stderrout], nil, nil, tick)
      # Try to read the data
      begin
        output << stderrout.read_nonblock(BUFFER_SIZE)
      rescue IO::WaitReadable
        # A read would block, so loop around for another select
      rescue EOFError
        # Command has completed, not really an error...
        break
      end
    end
    # Give Ruby time to clean up the other thread
    sleep 1

    if thread.alive?
      # We need to kill the process, because killing the thread leaves
      # the process alive but detached, annoyingly enough.
      Process.kill("TERM", pid)
    end
  ensure
    stdin.close if stdin
    stderrout.close if stderrout
  end
  return output
end

def run_c_profiler
  start = RubyOF::Utils.ofGetElapsedTimeMicros
  pid = Process.pid
  thr = Thread.new do
    now = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # min_delay = msec(3+16*60)
    # max_delay = msec(16+16*60)
    # rand_delay = ((max_delay - min_delay)*rand + min_delay).to_i
    # while now - start < rand_delay
    #   now = RubyOF::Utils.ofGetElapsedTimeMicros
    #   sleep(1)
    # end
    
    # # puts run_with_timeout('echo #{ENV["ROOT_PASSWORD"]} | sudo -S gdb -ex "set pagination 0" -ex "thread apply all bt" -batch -p '+"#{pid}", 5, 0.1)
    
    Dir.chdir GEM_ROOT/'vendor'/'quickstack-0.10-7' do
      
    #   run_with_timeout('./quickstack -f -p '+"#{pid}", 5, 0.1)
      puts `echo #{ENV["ROOT_PASSWORD"]} | sudo -S ./quickstack -f -p #{pid}`
    end
  end
  
  yield
  
  thr.join
end


RB_SPIKE_PROFILER = TracePoint.new(:call, :return, :c_call, :c_return) do |tp|
  
  # printf "%8s %s:%-2d %10s %8s\n", tp.event, tp.path.split("/").last, tp.lineno, tp.callee_id, tp.defined_class
  
  
  $spike_profiler_i ||= 0
  $spike_profiler_stack ||= Array.new
  
  flag = !([StateMachine].any?{|x| tp.defined_class.to_s == x.to_s })
  # (can't block Kernel - too many false positives)
  # flag = true
  
  # p tp.methods
  # puts tp.binding.source_location
  # ^ not defined in ruby 2.5 - but it is available in 2.7
  #   (not in backports either, so that's a dead end for now)
  
  case tp.event
  # when :call
  when :call, :c_call
    
    if $spike_profiler_i >=0 
      if flag
        # # puts "enter"
        # file_info = "#{tp.path.split('/').last}:#{tp.lineno}"
        method = "#{tp.defined_class}##{tp.callee_id}"
        # puts " #{$spike_profiler_stack.size}) #{method}"
        
        # # if method == "CharMappedDisplay#draw"
        # #   $spike_profiler_reset = true
        # # end
        
        # if method == "Array#index"
        #   puts tp.path.split('/').last
        #   puts caller if tp.path.split('/').last == 'char_mapped_display.rb'
        # end
      
        # $spike_profiler_stack << RubyOF::Utils.ofGetElapsedTimeMicros
        RubyOF::CPP_Callbacks.SpikeProfiler_begin(method)
      end
    end
    
    
    # puts ">> #{$spike_profiler_i}"
    
    # $spike_profiler_stack << RubyOF::Utils.ofGetElapsedTimeMicros
    $spike_profiler_i += 1
    
  # when :return
  when :return, :c_return
    
    if $spike_profiler_i > 0 
      if flag
        # file_info = "#{tp.path.split('/').last}:#{tp.lineno}"
        
        
        # # puts "return   #{tp.defined_class}##{tp.callee_id}"
        # start_time = $spike_profiler_stack.pop
        # now = RubyOF::Utils.ofGetElapsedTimeMicros
        # # puts start_time.inspect
        
        # dt = now - start_time
        # puts " #{$spike_profiler_stack.size})   dt = #{dt}"
        RubyOF::CPP_Callbacks.SpikeProfiler_end()
      end
      
      
    end
    
    # if $spike_profiler_reset and $spike_profiler_stack.size == 0
    #   $spike_profiler_reset = false
    #   puts "\n"*7
    # end
    
    $spike_profiler_i -= 1
    
    # puts "<< #{$spike_profiler_i}"
  end
  
end

def spike_profiler() # &block
  RB_SPIKE_PROFILER.enable do
    yield
  end
end


  
  
