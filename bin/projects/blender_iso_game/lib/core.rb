
# stores the main logic and data of the program

require 'forwardable' # for def_delegators

require 'json' # easiest way to transfer data between Python and Ruby
require 'base64'

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


load LIB_DIR/'entities'/'blender_object.rb'
load LIB_DIR/'entities'/'blender_mesh.rb'
load LIB_DIR/'entities'/'viewport_camera.rb'
load LIB_DIR/'entities'/'blender_light.rb'

class InstancingBuffer
  attr_reader :pixels, :texture
  
  def initialize
    @pixels = RubyOF::FloatPixels.new
    @texture = RubyOF::Texture.new
    
    @width = 256
    @height = 256
    @pixels.allocate(@width, @height)
    
    @texture.wrap_mode(:vertical => :clamp_to_edge,
                :horizontal => :clamp_to_edge)
    
    @texture.filter_mode(:min => :nearest, :mag => :nearest)
  end
  
  FLOAT_MAX = 1e10
  # https://en.wikipedia.org/wiki/Single-precision_floating-point_format#IEEE_754_single-precision_binary_floating-point_format:_binary32
  # 
  # I want to use 1e37 for this, or the nearest power of two.
  # The true float max is a little bigger, but this is enough.
  # This also allows for using one max for both positive and negative.
  def pack_positions(positions)
    positions.each_with_index do |pos, i|
      x = i / @width
      y = i % @width
      
      # puts pos
      arr = pos.to_a
      # arr = [1,0,0]
      
      magnitude_sq = arr.map{|i| i**2 }.reduce(&:+)
      magnitude = Math.sqrt(magnitude_sq)
      
      data = 
        if magnitude == 0
          posNorm = [0,0,0]
          posNormShifted = posNorm.map{|i| (i+1)/2 }
          
          [*posNormShifted, 0]
        else
          posNorm = arr.map{|i| i / magnitude }
          posNormShifted = posNorm.map{|i| (i+1)/2 }
          
          magnitude_normalized = magnitude / FLOAT_MAX
          
          
          [*posNormShifted, magnitude_normalized]
        end
      
      color = RubyOF::FloatColor.rgba(data)
      # p color.to_a
      @pixels.setColor(x,y, color)
    end
    
    # same logic as above, but need to make sure ofColorFloat
    # RubyOF::CPP_Callbacks.pack_positions(@pixels, @width, @height)
    
    
    # _pixels->getColor(x,y);
    # _tex.loadData(_pixels, GL_RGBA);
    @texture.load_data(@pixels)
    
  end
  
  def max_instances
    return @width*@height
  end
end


load LIB_DIR/'blender_sync.rb'


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
    @first_draw = true
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
    
    
    
    @entities = {
      'viewport_camera' => ViewportCamera.new,
      
      'Light' => BlenderLight.new
    }
    
    @meshes = Hash.new
    
    
    @sync = BlenderSync.new(@w, @entities, @meshes)
    
    
    @world_save_file = PROJECT_DIR/'bin'/'data'/'world_data.yaml'
    if @world_save_file.exist?
      puts "loading 3D graphics data..."
      camera_data = YAML.load_file @world_save_file
      puts "load complete!"
      p camera_data
      
      
      @sync.parse_blender_data(camera_data)
      
      @entities['viewport_camera'].dirty = false
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
    
    
    save_world_state()
    
  end
  
  
  def on_reload
    puts "core: on reload"
    unless @crash_detected
      # on a successful reload after a normal run with no errors,
      # need to free resources from the previous normal run,
      # because those resources will be initialized again in #setup
      self.ensure()
      
      # Save world on successful reload without crash,
      # to prevent discontinuities. Otherwise, you would
      # need to manually refresh the Blender viewport
      # just to see the same state that you had before reload.
      save_world_state()
    end
    
    @crash_detected = false
    
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
    
    # Some errors may prevent sync object from being initialized.
    # In that case, you can get a double-crash if you try to run
    # BlenderSync#stop.
    @sync.stop unless @sync.nil?
  end
  
  
  def save_world_state
    # 
    # save 3D graphics data to file
    # 
    
    puts "saving world to file.."
    entity_data_list = 
      @entities.to_a.collect{ |key, val|
        val.data_dump
      }
    
    
    # obj['view_perspective'] # [PERSP', 'ORTHO', 'CAMERA']
    # ('CAMERA' not yet supported)
    # ('ORTHO' support currently rather poor)
    
    
    # TODO: start saving to disk again once the mesh data exchange is finalized
    # dump_yaml entity_data_list => @world_save_file
    puts "world saved!"
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
    
    scheduler.section name: "sync ", budget: msec(5.0)
      @sync.update
    
    
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
    # setup materials, etc
    # 
    if @first_draw
      # ofBackground(10, 10, 10, 255);
      # // turn on smooth lighting //
      ofSetSmoothLighting(true)
      
      ofSetSphereResolution(32)
      
      
      
      @mat1 ||= RubyOF::Material.new
      # @mat1.diffuse_color = RubyOF::FloatColor.rgb([0, 1, 0])
      @mat1.diffuse_color = RubyOF::FloatColor.rgb([1, 1, 1])
      # // shininess is a value between 0 - 128, 128 being the most shiny //
      @mat1.shininess = 64
      
      
      
      @mat2 ||= RubyOF::Material.new
      # ^ update color of this material every time the light color changes
      #   not just on the first frame
      #   (creating the material is the expensive part anyway)
      
      
      
      @mat_instanced ||= RubyOF::OFX::InstancingMaterial.new
      @mat_instanced.diffuse_color = RubyOF::FloatColor.rgb([1, 1, 1])
      @mat_instanced.shininess = 64
      
      
      @shader_timestamp = nil
      
      shader_src_dir = PROJECT_DIR/"ext/c_extension/shaders"
      @vert_shader_path = shader_src_dir/"phong_instanced.vert"
      @frag_shader_path = shader_src_dir/"phong.frag"
      
      
      
      
      @first_draw = false
      
    end
    
    # load shaders if they have never been loaded before,
    # or if the files have been updated
    if @shader_timestamp.nil? || [@vert_shader_path, @frag_shader_path].any?{|f| f.mtime > @shader_timestamp }
      
      
      vert_shader = File.readlines(@vert_shader_path).join("\n")
      frag_shader = File.readlines(@frag_shader_path).join("\n")
      
      @mat_instanced.setVertexShaderSource vert_shader
      @mat_instanced.setFragmentShaderSource frag_shader
      
      
      @shader_timestamp = Time.now
      
      puts "shader reloaded"
    end
    
    
    
    
    @entities['viewport_camera'].begin
      
      ofEnableDepthTest()
        # // enable lighting //
        ofEnableLighting()
        # // the position of the light must be updated every frame,
        # // call enable() so that it can update itself //
        @entities['Light'].enable()
        
          # // render objects in world
            
          batching = 
            @entities.values
            .select{|x| x.is_a? BlenderMesh }
            .group_by{|x| x.mesh }
          
          # p batching.collect{|k,v|  [k.class, v.size]}
          
          
          
          batching.each do |mesh_data, mesh_objs|
            
            # mesh_obj.mesh.generate_normals()
            # ^ yes, generating normals does make the light function... better, but these particular normals are extremely bad...
            
            
            if mesh_objs.size > 1
              # draw instanced
              
              # 
              # v4 - translation + z-rot, stored in texture
              # 
              
              @instance_data ||= InstancingBuffer.new
              
              
              # collect up all the transforms
              positions = 
                mesh_objs.collect do |mesh_obj|
                  mesh_obj.node.position
                end
              
              
              # raise exception current texture size is too small
              # to hold packed position information.
              max_instances = @instance_data.max_instances
              
              if positions.size > max_instances
                msg = [
                  "ERROR: Too many instances to draw using one position texture. Need to implement spltting them into separate batches, or something like that.",
                  "Current maximum: #{max_instances}",
                  "Instances requested: #{positions.size}"
                ]
                
                raise msg.join("\n")
              end
              
              # pack into image -> texture (which will be passed to shader)
              @instance_data.pack_positions(positions)
              
              # set uniforms
              @mat_instanced.setCustomUniformTexture(
                "position_tex", @instance_data.texture, 1
              )
              
              @mat_instanced.setInstanceMagnitudeScale(
                InstancingBuffer::FLOAT_MAX
              )
              
              
              # but how is the primary texture used to color the mesh in the fragment shader bound? there is some texture being set to 'tex0' but I'm unsure where in the code that is actually specified
              
              
              @mat_instanced.begin()
              
              # draw all the instances using one draw call
              mesh_data.draw_instanced(mesh_objs.size)
              
              @mat_instanced.end()
              
              
              
              
              # ext/openFrameworks/examples/gl/vboMeshDrawInstancedExample/src/ofApp.cpp
              # ext/openFrameworks/libs/openFrameworks/gl/ofMaterial.cpp
              # bin/projects/blender_iso_game/ext/c_extension/ofxInstancingMaterial.cpp
              
              # # TODO: bind Vbo#setAttributeData()
              # # TODO: bind Node#getLocalTransforMatrix
              # # TODO: bind Node#getGlobalTransformMatrix
              #     obj.node.position
              
              
                
              #   # https://forum.openframeworks.cc/t/how-to-set-custom-data-to-ofvbo/18296
              #   # 
              #   # ^ great explanation here of how to get the data into the shader. but I still need to figure out how to make this work with materials.

              # https://forum.openframeworks.cc/t/opengl-wrapper-vbo-and-shader-location/24760
              
              
              
            else 
              # draw just a single object
              
              mesh_obj = mesh_objs.first
              
              @mat1.begin()
                mesh_obj.node.transformGL()
                mesh_data.draw()
                mesh_obj.node.restoreTransformGL()
              @mat1.end()
            end
            
            # TODO: eventually want to unify the materials, so you can use the same material object for single objects and instanced draw, but this setup will work for the time being. (Not sure if it will collapse into a single shader, but at least can be one material)
            
            
          end
          
          
          # 
          # render the sphere that represents the light
          # 
          
          light_pos = @entities['Light'].position
          light_color = @entities['Light'].diffuse_color
          @mat2.emissive_color = light_color
          
            
          @mat2.begin()
          ofPushMatrix()
            ofDrawSphere(light_pos.x, light_pos.y, light_pos.z, 0.1)
          ofPopMatrix()
          @mat2.end()
        
        # // turn off lighting //
        @entities['Light'].disable()
        ofDisableLighting()
      ofDisableDepthTest()
    
    @entities['viewport_camera'].end
    
    
    
    # NOTE: ofMesh is not a subclass of ofNode, but ofLight and ofCamera ARE
    # (thus, you don't need a separate node to track the position of ofLight)
    
    # if @first_update
    #   # ofEnableDepthTest()
    #   # @entities['Light'].setup
      
      
    #   # @first_update = false
    # end
    
    
    
    
    # 
    # render text display
    # 
    
    # @display.draw()
  end
  
  def camera_begin
    @entities['viewport_camera'].begin
  end
  
  def camera_end
    @entities['viewport_camera'].end
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


  
  
