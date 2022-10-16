
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


# Do not call this "Time" to avoid collision with Kernel::Time
module RubyOF
  class TimeCounter
    class << self
      def reset
        ofResetElapsedTimeCounter()
      end
      
      def delta(t1, t0)
        return t1 - t0
      end
      
      def now
        return new(RubyOF::Utils.ofGetElapsedTimeMicros)
      end
    end
    
    attr_accessor :t
    
    def initialize(t)
      @t = t # store time in microseconds
    end
    
    
    
    def -(other)
      raise "ERROR: can't subtract #{other.class} from #{self.class}" unless other.is_a? self.class
      
      
      # TODO: how to deal with rollover?
      return self.class.new(@t - other.t)
    end
    
    # convert to milliseconds (usec -> msec)
    def to_ms
      return @t.to_f / 1000
    end
    
    # convert to microseconds (usec -> usec)
    def to_us
      return @t
    end
    
    def to_s
      return "#{@t} microseconds"
    end
  end
end



load LIB_DIR/'patches'/'cpp_callbacks.rb'

load LIB_DIR/'entities'/'blender_material.rb'
load LIB_DIR/'entities'/'blender_object.rb'
load LIB_DIR/'entities'/'blender_mesh.rb'
load LIB_DIR/'entities'/'viewport_camera.rb'
load LIB_DIR/'entities'/'blender_light.rb'


load LIB_DIR/'blender_history.rb'
load LIB_DIR/'blender_sync.rb'

# load LIB_DIR/'instancing_buffer.rb'
load LIB_DIR/'fixed_schema_tree.rb'
load LIB_DIR/'my_state_machine.rb'
load LIB_DIR/'world.rb'

load LIB_DIR/'oit_render_pipeline.rb'










class Core
  include HelperFunctions
  
  attr_accessor :sync
  
  def initialize(window)
    @window = window
  end
  
  def setup
    puts "core: setup"
    
    ofBackground(200, 200, 200, 255)
    # ofEnableBlendMode(:alpha)
    
    
    @first_update = true
    @first_draw = true
    @mouse = CP::Vec2.new(0,0)
    
    
    @midi_msg_memory = SequenceMemory.new
    # @input_handler = InputHandler.new
    
    
    
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
    
    
    
    
    
    
    @world_save_file = PROJECT_DIR/'bin'/'data'/'world_data.yaml'
    
    
    
    
    
    # want these created once, and not reloaded when code is reloaded.
    # @world is reloaded with reloading of new code,
    # then it can clobber the positions loaded by @frame_history
    # (or maybe we can reload @world in on_reload, BEFORE @frame_history)
    
    # 
    # OpenEXR animation texture test
    # 
    
    data_dir = (PROJECT_DIR/'bin'/'data')
    geometry_texture_dir = data_dir/'geom_textures'
    
    @world = World.new(data_dir/'geom_textures')
    
    @world.setup()
    
    @camera_save_file = PROJECT_DIR/'bin'/'data'/'camera.yaml'
    if @camera_save_file.exist?
      data = YAML.load_file @camera_save_file
      @world.camera.load data
    end
    
    @lighting_save_file = PROJECT_DIR/'bin'/'data'/'lights.yaml'
    if @lighting_save_file.exist?
      data = YAML.load_file @lighting_save_file
      @world.lights.load data
    end
    
    @world.entities.each_with_index do |entity, i|
      puts "#{i.to_s.rjust(4)} : #{entity.name}"
    end
    
    
    
    # material invokes shaders
    @material = BlenderMaterial.new "OpenEXR vertex animation mat"
    
    shader_src_dir = PROJECT_DIR/"bin/glsl"
    @vert_shader_path = shader_src_dir/"animation_texture.vert"
    # @frag_shader_path = shader_src_dir/"phong_test.frag"
    @frag_shader_path = shader_src_dir/"phong_anim_tex.frag"
    
    # @material.diffuse_color = RubyOF::FloatColor.rgba([1,1,1,1])
    # @material.specular_color = RubyOF::FloatColor.rgba([0,0,0,0])
    # @material.emissive_color = RubyOF::FloatColor.rgba([0,0,0,0])
    # @material.ambient_color = RubyOF::FloatColor.rgba([0.2,0.2,0.2,0])
    
    
    @render_pipeline = OIT_RenderPipeline.new
    
    
    @sync = BlenderSync.new(@window, @world)
    
  end
  
  # always run on exit, right before window is closed
  def on_exit
    puts "core: on exit"
    
    # if @crash_detected
      self.ensure()
    # end
    
    
    if RB_SPIKE_PROFILER.enabled?
      RB_SPIKE_PROFILER.disable
    end
    
    
    dump_yaml @world.camera.data_dump => @camera_save_file
    dump_yaml @world.lights.data_dump => @lighting_save_file
    
    
    # FileUtils.rm @world_save_file if @world_save_file.exist?
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
    
    # TODO: seems like the thread is ending, but the FIFO file is left standing. Need to at least close the file from the reader side, even if the actual named pipe "file" is left standing.
      # If the named pipe is closed, subsequent writes should recieve the SIGPIPE signal (broken pipe) which should allow me to deal with hanging stuff from Blender
  end
  
  
  
  
  
  # run when exception is detected
  def on_crash
    puts "core: on_crash"
    @crash_detected = true
    
    @world.on_crash(@sync)
    
    # TODO: handle unrecoverable exception differently than recoverable exception
      # unrecoverable exceptions lead to program exit, rather than potential for reload. this can mean that @sync is not shut down correctly, and the FIFO remains open. need a way to detect these sorts of execptions reliably, so that the FIFO can be closed. However, during most exceptions, you want to leave the FIFO open so that Blender controls can be used for time travel, which is critical for debugging a crash.
    
    
    # Don't stop sync thread on crash.
    # Need to be able to communicate with Blender
    # in order to control time travel
    
    # self.ensure()
  end
  
  def update_while_crashed
    self.update()
  end
  
  # NOTE: behavior is undefined if system crashes during #setup
  def on_reload
    puts "core: on_reload() BEGIN"
    
    # if !@crash_detected
      # on a successful reload after a normal run with no errors,
      # need to free resources from the previous normal run,
      # because those resources will be initialized again in #setup
      
      # self.ensure()
        # ^ ensure closes @sync                               Core#ensure
        #   which sends "sync_stopping" message to blender    BlenderSync#stop
        #   which is processed in python                      main_file.py
        #   which clamps the blender timeline, similar to pausing,
        #   which causes a pause signal to be sent from blender to ruby
        #   which then pauses execution.
        #   
      
    # end
    
    @crash_detected = false
    
    # @world.space.update
    
    # setup()
      # (need to re-start sync, because the IO thread is stopped in the ensure callback)
      # puts "restart sync"
      # @sync.reload
      # |--> World#on_reload_code(@sync)
      
      @world.on_reload_code(@sync)
    
    
    
    
    @first_update = true
    puts "core: on_reload() END"
    
    
    # load_world_state()
  end
  
  
  # Propagates signal from FrameHistory back up to LiveCode
  # that the problem which caused the crash has been managed,
  # even without loading new code.
  def in_error_state?
    @crash_detected
  end
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  def window_resized(w,h)
    # puts "generate new camera"
    # @world.camera = ViewportCamera.new
    @render_pipeline.update(@window, @world.lights)
  end
  
  
  
  
  
  
  
  
  
  
  def free_space?(pos)
    return !blocked_space?(pos)
  end
  
  def blocked_space?(pos)
    @world.space.point_query(pos)
    .any?{|mesh| mesh.solid? } # are there any solid blocks @ pos?
  end
  
  
  # use a structure where Fiber does not need to be regenerated on reload
  def update
    # @update_scheduler ||= Scheduler.new(self, :on_update, msec(16-4))
    
    # # puts ">>>>>>>> update #{RubyOF::Utils.ofGetElapsedTimeMicros}"
    # @start_time = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # # puts "update thread: #{Thread.current.object_id}" 
    
    # # if SPIKE_PROFILER_ON
    # #   RB_SPIKE_PROFILER.enable
    # # end
    
    # # puts "--> start update"
    # signal = @update_scheduler.resume
    # # puts signal
    # # puts "<-- end update"
    
    # # if SPIKE_PROFILER_ON
    # #   RB_SPIKE_PROFILER.disable
    # #   puts "\n"*7
    # # end
    
    
    if @first_update
      puts "first update"
      # load_world_state()
      
      @first_update = false
    end
    
    @material.load_shaders(@vert_shader_path, @frag_shader_path) do
      # on reload
      
    end
    
    @sync.update
    
    # binding needs to happen during Core#update, otherwise weird things
    # can happen with Fiber context
    @world.bind_update_block do |snapshot|
      # step every x frames
      x = 8
      
      moves = [
        GLM::Vec3.new(1, 0, 0),
        GLM::Vec3.new(1, 0, 0),
        GLM::Vec3.new(0, 1, 0),
        GLM::Vec3.new(0, 1, 0),
        GLM::Vec3.new(0, 1, 0),
        GLM::Vec3.new(0, 1, 0),
        GLM::Vec3.new(0, 1, 0),
        GLM::Vec3.new(0, 1, 0),
        GLM::Vec3.new(0, 1, 0),
        GLM::Vec3.new(0, 1, 0),
        GLM::Vec3.new(-1, 0, 0),
        GLM::Vec3.new(-1, 0, 0),
        GLM::Vec3.new(0, 1, 0),
      ]
      
      
      moves.each_with_index do |v, move_idx|
        # step in a direction, but subdivide into
        # two motions for animation / tweening
        
        # puts "move idx: #{move_idx} of #{moves.length-1}"
        
        
        
        #  0 - log root position
        snapshot.frame do
          puts "hello world"
        end
        
        
        # transform could be set on frame 0 (e.g. the very first frame)
        # so want to load the transform data after that
        
        # all code inside snapshot blocks will be skipped on resume
        # so any code related to a branch condition
        # needs to be outside of the snapshot blocks.
        
        entity = @world.entities['CharacterTest']
        p entity
        
        pos = entity.position
        puts "grid position: #{pos}"
        
        
        
        
        
        
        
        
        # if the spot in front of you is open (flat ground), move forward
        
        # if the spot in front of you is blocked, step up onto the block
          # obstruction must be 1 block tall
          # if it is taller, then you can't step over
          
          # step up and then over in the direction you originally planned to go
          
        # if the spot in front of you is open (hole), fall down into the hole
          # need 1 blocks open for your body to fit
          # and then also your feet need to be unsupported
        
        
        v_up   = GLM::Vec3.new(0,0,1)
        v_down = GLM::Vec3.new(0,0,-1)
        
        
        # try to move up
        # make sure front is blocked AND there is open space above
        if blocked_space?(pos + v) && free_space?(pos + v_up)
          #  1 - animate
          snapshot.frame do
            puts "step up: #{pos} -> #{pos + v_up}"
          end
          
          15.times do
            #  2..16 - animate
            snapshot.frame do
              # NO-OP
            end
          end
          
          # 17 - animate
          snapshot.frame do
            entity.position = pos + v_up
          end
          
          
          
          #  0 - new root position
          snapshot.frame do
            
          end
          
          # 
          # update pos = new root position
          # 
          pos = entity.position
          
        end
        
        
        # try to move forward
        # as long as the way is clear, move forward (even if you would fall)
        if free_space?(pos + v)
          
          #  1 - animate
          snapshot.frame do
            puts "move forward: #{pos} -> #{pos + v}"
          end
          
          15.times do
              #  2..16 - animate
              snapshot.frame do
                # NO-OP
              end
            end
          
          # 17 - animate
          snapshot.frame do
            entity.position = pos + v
          end
          
          #  0 - new root position
          snapshot.frame do
            
          end
          
          
          # 
          # update pos = new root position
          # 
          pos = entity.position
          
          
        end
        
        # try to move down
        while free_space?(pos + v_down)
          
          #  1 - animate
          snapshot.frame do
            puts "falling: #{pos} -> #{pos + v_down}"
          end
          
          15.times do
              #  2..16 - animate
              snapshot.frame do
                # NO-OP
              end
            end
          
          # 17 - animate
          snapshot.frame do
            entity.position = pos + v_down
            # puts "falling"
          end
          
          #  0 - new root position
          snapshot.frame do
            # puts "falling"
          end
          
          
          # 
          # update pos = new root position
          # 
          pos = entity.position
          
          
          
        end
        
        
      end
      
    end
    
    @world.update @sync
    # normal update block executes while code is crashed.
    
    # 
    # The World#update block may be skipped, but the state machine etc
    # will continue to update. If the crash is resolved,
    # we will see that signal here, and help propagate it up to LiveCode
    # ( signal is actually sent to LiveCode in Core#in_error_state? )
    if @world.crash_resolved?
      @crash_detected = false # reset when normal updates can run again
    end
  end
  
  # methods #update and #draw are called by the C++ render loop
  # Their only job now at the Ruby level is to set up Fibers
  # which call the true render logic. This structure is necessary
  # to allow for live loading - if the update / draw logic
  # is directly inside the Fiber, there's no good way to reload it
  # when the file reloads
  
  
  
  
  include RubyOF::Graphics
  def draw
    
    
    
    # 
    # setup materials, etc
    # 
    # if @first_draw
      
    #   @first_draw = false
      
    # end
    
    
    
    
    # 
    # set up phases of drawing
    # 
    
    @render_pipeline.draw(@window,
                          lights:@world.lights,
                          camera:@world.camera,
                          material:@material) do |pipeline|
      
      # TODO: need to handle opaque shadow casters separately from transparent shadow casters. opaque shadow casters merely block light, but transparent shadow casters modify the color of the light while also reducing its intensity.
      pipeline.shadow_pass do |lights, shadow_material|
        # for now, render opaque objects only
        
        @world.batches.each do |b|
          # set uniforms
          shadow_material.setCustomUniformTexture(
            "vert_pos_tex",  b[:mesh_data][:textures][:positions], 1
          )
          
          shadow_material.setCustomUniformTexture(
            "vert_norm_tex", b[:mesh_data][:textures][:normals], 2
          )
          
          shadow_material.setCustomUniformTexture(
            "entity_tex", b[:entity_data][:texture], 3
          )
          
          shadow_material.setCustomUniform1f(
            "transparent_pass", 0
          )
          
          # draw using GPU instancing
          using_material shadow_material do
            instance_count = b[:entity_data][:pixels].height.to_i
            b[:geometry].draw_instanced instance_count
          end
        end
      end
      
      
      # NOTE: transform matrix for light space set in oit_render_pipeline before any objects are drawn
      pipeline.opaque_pass do
        @world.batches.each do |b|
          # set uniforms
          @material.setCustomUniformTexture(
            "vert_pos_tex",  b[:mesh_data][:textures][:positions], 1
          )
          
          @material.setCustomUniformTexture(
            "vert_norm_tex", b[:mesh_data][:textures][:normals], 2
          )
          
          @material.setCustomUniformTexture(
            "entity_tex", b[:entity_data][:texture], 3
          )
          
          @material.setCustomUniform1f(
            "transparent_pass", 0
          )
          
          # draw using GPU instancing
          using_material @material do
            instance_count = b[:entity_data][:pixels].height.to_i
            b[:geometry].draw_instanced instance_count
          end
        end
        
        # glCullFace(GL_BACK)
        # glDisable(GL_CULL_FACE)
      end
      
      # NOTE: transform matrix for light space set in oit_render_pipeline before any objects are drawn
      pipeline.transparent_pass do
        @world.batches.each do |b|
          # set uniforms
          @material.setCustomUniformTexture(
            "vert_pos_tex",  b[:mesh_data][:textures][:positions], 1
          )
          
          @material.setCustomUniformTexture(
            "vert_norm_tex", b[:mesh_data][:textures][:normals], 2
          )
          
          @material.setCustomUniformTexture(
            "entity_tex", b[:entity_data][:texture], 3
          )
          
          @material.setCustomUniform1f(
            "transparent_pass", 1
          )
          
          # draw using GPU instancing
          using_material @material do
            instance_count = b[:entity_data][:pixels].height.to_i
            b[:geometry].draw_instanced instance_count
          end
        end
        
        # while time traveling, render the trails of moving objects
        if @world.transport.time_traveling?
          
        end
      end
      
      pipeline.ui_pass do
        # t0 = RubyOF::TimeCounter.now
        
        
        p1 = CP::Vec2.new(500,500)
        @fonts[:monospace].draw_string("hello world!",
                                       p1.x, p1.y)
        
        
        
        p2 = CP::Vec2.new(500,600)
        if @mouse_pos
          
          @fonts[:monospace].draw_string("mouse: #{@mouse_pos.to_s}",
                                         p2.x, p2.y)
        end
        
        
        @fonts[:monospace].tap do |f|
          
          f.draw_string("frame #{@world.transport.current_frame}/#{@world.transport.final_frame}",
                                           1178, 846+40)
          
          f.draw_string("state #{@world.transport.current_state.class.to_s}",
                                           1178, 846)
        end
        
        # @fonts[:monospace].draw_string("history size: #{}",
                                         # 400, 160)
        
        
        p3 = CP::Vec2.new(646, 846)
        @fonts[:monospace].tap do |f|
          f.draw_string("camera", p3.x, p3.y+40*0)
          f.draw_string("Handglovery", p3.x, p3.y+40*1)
        
          f.draw_string("#{@world.camera.position.to_s}", p3.x, p3.y+40*2)
          
          dist = @world.camera.position.yield_self do |x|
            x.to_a[0..1]
             .map{|x| x*x}
             .reduce(:+)
             .yield_self{|x| Math.sqrt(x) }
          end
          f.draw_string("#{ dist }}", p3.x, p3.y+40*3)
        end
        
        # ^ this debug output demonstrates that the position of the ortho camera is not the same as the position of the perspective camera. hopefully the shadow camera will still work as expected
        
        
        # t1 = RubyOF::TimeCounter.now
        # puts "=> UI    : #{(t1 - t0).to_ms} ms"
        
        
        # @texture_out.draw_wh(500,50,0, @pixels.width, @pixels.height)
        
        @world.draw_ui( @fonts[:monospace] )
        
        
        # stuff we need to render with this
          # + a programatically created mesh with triangles to mutate
          # + a material to hold the vertex and fragment shaders
          # + vertex shader <---  this is what does the heavy lifting
          # + frag shader (just load the default one)
        
        # TODO: update serialization code for blender_material etc, as their YAML conversions no longer match the new JSON message format (or maybe I can get rid of that entirely, and just maintain JSON message history??)
        
        @crash_color ||= RubyOF::Color.hex_alpha(0xff0000, 20)
        if @crash_detected
          
          ofPushStyle()
            ofEnableAlphaBlending()
            ofSetColor(@crash_color)
            ofDrawRectangle(0,0,0, @window.width, @window.height)
          ofPopStyle()
        end
        
        
      end
    end
    
    
    
    # t1 = RubyOF::TimeCounter.now
    # puts "=> scene : #{(t1 - t0).to_ms} ms"
    
    
  end
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  def key_pressed(key)
    # @input_handler.key_pressed(key)
  end
  
  def key_released(key)
    # @input_handler.key_released(key)
  end
  
  
  
  # 
  # mouse prints position in character grid to STDOUT
  # 
  
  def mouse_moved(x,y)
    @mouse_pos = CP::Vec2.new(x,y)
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


  
  
