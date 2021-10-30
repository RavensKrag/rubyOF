
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

load LIB_DIR/'instancing_buffer.rb'

load LIB_DIR/'blender_history.rb'
load LIB_DIR/'render_batch.rb'
load LIB_DIR/'dependency_graph.rb'
load LIB_DIR/'blender_sync.rb'



load LIB_DIR/'vertex_animation_batch.rb'
load LIB_DIR/'frame_history.rb'



# order independent transparency render pipeline
class OIT_RenderPipeline
  
  def initialize
    @light_material = RubyOF::Material.new
    # ^ material used to visualize lights a small spheres in space.
    # color of this material may change for every light
    # so every light is rendered as a separate batch,
    # even though they all use the same sphere mesh.
    # (would need something like Unity's MaterialPropertyBlock to avoid this)
    # (for now, seems like creating the material is the expensive part anyway)
    
    
    # ^ materials used to visualize lights a small spheres in space
    # (basically just shows the color and position of each light)
    # (very important for debugging synchronization between RubyOF and blender)
  end
  
  class Helper
    EMPTY_BLOCK = Proc.new{  }
    
    def initialize
      @opaque_pass      = EMPTY_BLOCK
      @transparent_pass = EMPTY_BLOCK
      @ui_pass          = EMPTY_BLOCK
    end
    
    def opaque_pass(&block)
      @opaque_pass = block
    end
    
    def transparent_pass(&block)
      @transparent_pass = block
    end
    
    def ui_pass(&block)
      @ui_pass = block
    end
    
    def get_render_passes
      return @opaque_pass, @transparent_pass, @ui_pass
    end
    
  end
  
  
  
  COLOR_ZERO = RubyOF::FloatColor.rgba([0,0,0,0])
  COLOR_ONE  = RubyOF::FloatColor.rgba([1,1,1,1])
  
  include RubyOF::Graphics
  include Gl
  def draw(window, camera:nil, lights:nil, &block)
    helper = Helper.new
    block.call(helper)
    
    @opaque_pass,@transparent_pass,@ui_pass = helper.get_render_passes
    
    
    
    # ofEnableAlphaBlending()
    # # ^ doesn't seem to do anything, at least not right now
    
    # ofEnableBlendMode(:alpha)
    
    # ofBackground(10, 10, 10, 255);
    # // turn on smooth lighting //
    ofSetSmoothLighting(true)
    
    ofSetSphereResolution(32) # want higher resoultion than the default 20
    # ^ this is used to visualize the color and position of the lights
    
    
    
    # 
    # parameters
    # 
    
    accumTex_i     = 0
    revealageTex_i = 1
    
    
    # 
    # setup
    # 
    
    RubyOF::Fbo::Settings.new.tap do |s|
      s.width  = window.width
      s.height = window.height
      s.internalformat = GL_RGBA32F_ARB;
      # s.numSamples     = 0; # no multisampling
      s.useDepth       = true;
      s.useStencil     = false;
      s.depthStencilAsTexture = true;
      
      s.textureTarget  = GL_TEXTURE_RECTANGLE_ARB;
      
      @main_fbo ||= 
        RubyOF::Fbo.new.tap do |fbo|
          s.clone.tap{ |s|
            
            s.numColorbuffers = 1;
            
          }.yield_self{ |s| fbo.allocate(s) }
        end
      
      @transparency_fbo ||= 
        RubyOF::Fbo.new.tap do |fbo|
          s.clone.tap{ |s|
            
            s.numColorbuffers = 2;
            
          }.yield_self{ |s| fbo.allocate(s) }
        end
    end
    
    @compositing_shader ||= RubyOF::Shader.new
    
    
    if @tex0.nil?
      @tex0 = @transparency_fbo.getTexture(accumTex_i)
      @tex1 = @transparency_fbo.getTexture(revealageTex_i)
      
      @fullscreen_quad = 
        @tex0.yield_self{ |texure|
          RubyOF::CPP_Callbacks.textureToMesh(texure, GLM::Vec3.new(0,0,0))
        }
    end
    
    
    # 
    # update
    # 
    
    
    (PROJECT_DIR/'bin'/'glsl').tap do |shader_src_dir|
      @compositing_shader.live_load_glsl(
        shader_src_dir/'alpha_composite.vert',
        shader_src_dir/'alpha_composite.frag'
      ) do
        puts "alpha compositing shaders reloaded"
      end
    end
    
    
    
    # ---------------
    #   world space
    # ---------------
    
    
    # McGuire, M., & Bavoil, L. (2013). Weighted Blended Order-Independent Transparency. 2(2), 20.
      # Paper assumes transparency encodes occlusion and demonstrates
      # how OIT works with colored smoke and clear glass.
      # 
      # Follow-up paper in 2016 demonstrates improvements,
      # including work with colored glass.
    
    # 
    # setup GL state
    # ofEnableDepthTest()
    ofEnableLighting() # // enable lighting //
    ofEnableDepthTest()
    
    lights.each{ |light|  light.enable() }
    
    
    
    using_framebuffer @main_fbo do |fbo|
      # NOTE: must bind the FBO before you clear it in this way
      fbo.clearDepthBuffer(1.0) # default is 1.0
      fbo.clearColorBuffer(0, COLOR_ZERO)
      
      using_camera camera do
        # puts "light on?: #{@lights[0]&.enabled?}" 
        
        @opaque_pass.call()
        
        
        # visualize lights
        # render colored spheres to represent lights
        lights.each do |light|
          light_pos   = light.position
          light_color = light.diffuse_color
          
          @light_material.tap do |mat|
            mat.emissive_color = light_color
            
            
            # light.draw
            mat.begin()
            ofPushMatrix()
              ofDrawSphere(light_pos.x, light_pos.y, light_pos.z, 0.1)
            ofPopMatrix()
            mat.end()
          end
        end
      end
    end
    
    
    blit_framebuffer :depth_buffer, @main_fbo => @transparency_fbo
    # RubyOF::CPP_Callbacks.blitDefaultDepthBufferToFbo(fbo)
    
    
    using_framebuffer @transparency_fbo do |fbo|
      # NOTE: must bind the FBO before you clear it in this way
      fbo.clearColorBuffer(accumTex_i,     COLOR_ZERO)
      fbo.clearColorBuffer(revealageTex_i, COLOR_ONE)
      
      RubyOF::CPP_Callbacks.enableTransparencyBufferBlending()
      
      using_camera camera do
        @transparent_pass.call()
      end
      
      
      RubyOF::CPP_Callbacks.disableTransparencyBufferBlending()      
    end
    
    
    lights.each{ |light|  light.disable() }
    
    # teardown GL state
    ofDisableDepthTest()
    ofDisableLighting()
    
    # ----------------
    #   screen space
    # ----------------
    
    
    # RubyOF::CPP_Callbacks.clearDepthBuffer()
    # RubyOF::CPP_Callbacks.depthMask(true)
    
    # ofEnableBlendMode(:alpha)
    
    
    
    
    @main_fbo.draw(0,0)
    
    
    RubyOF::CPP_Callbacks.enableScreenspaceBlending()
    
    using_shader @compositing_shader do
      using_textures @tex0, @tex1 do
        @fullscreen_quad.draw()
      end
    end
    # draw_fbo_to_screen(@transparency_fbo, accumTex_i, revealageTex_i)
    # @transparency_fbo.draw(0,0)
    
    RubyOF::CPP_Callbacks.disableScreenspaceBlending()
    
    
    
    
    
    @ui_pass.call()
    
  end
  
  private
  
  def blit_framebuffer(buffer_name, hash={})
    src = hash.keys.first
    dst = hash.values.first
    
    buffer_flag = 
      case buffer_name
      when :color_buffer
        0b01
      when :depth_buffer
        0b10
      when :both
        0b11
      else
        0x00
      end
    
    RubyOF::CPP_Callbacks.copyFramebufferByBlit__cpp(
      src, dst, buffer_flag
    )
  end
  
  def using_camera(camera) # &block
    exception = nil
    
    begin
      # camera begin
      camera.begin
      
      
      # (world space rendering block)
      yield
      
      
    rescue Exception => e 
      exception = e # supress exception so we can exit cleanly first
    ensure
      
      
      # camera end
      camera.end
      
      # after cleaning up, now throw the exception if needed
      unless exception.nil?
        raise exception
      end
      
    end
  end
  
  
  # TODO: add exception handling here, so gl state set by using the FBO / setting special blending modes doesn't leak
  def using_framebuffer fbo # &block
    fbo.begin
      fbo.activateAllDrawBuffers() # <-- essential for using mulitple buffers
      # ofEnableDepthTest()
      
      
      # glDepthMask(GL_FALSE)
      # glEnable(GL_BLEND)
      # glBlendFunci(0, GL_ONE, GL_ONE) # summation
      # glBlendFunci(1, GL_ZERO, GL_ONE_MINUS_SRC_ALPHA) # product of (1 - a_i)
      # RubyOF::CPP_Callbacks.enableTransparencyBufferBlending()
      
        yield fbo
      
      # RubyOF::CPP_Callbacks.disableTransparencyBufferBlending()
      
      # ofDisableDepthTest()
    fbo.end
  end
  
  # void ofFbo::updateTexture(int attachmentPoint)
  
    # Explicitly resolve MSAA render buffers into textures
    # \note if using MSAA, we will have rendered into a colorbuffer, not directly into the texture call this to blit from the colorbuffer into the texture so we can use the results for rendering, or input to a shader etc.
    # \note This will get called implicitly upon getTexture();
  

end


































class Core
  include HelperFunctions
  
  attr_accessor :frame_history
  attr_accessor :sync
  
  def initialize(window)
    @w = window
  end
  
  def setup
    puts "core: setup"
    
    ofBackground(200, 200, 200, 255)
    # ofEnableBlendMode(:alpha)
    
    
    @draw_durations = Array.new # stores profiler data for #draw
    
    
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
    
    
    
    @message_history = BlenderHistory.new
    @depsgraph = DependencyGraph.new
    @sync = BlenderSync.new(@w, @depsgraph, @message_history, self)
    
    
    
    
    @world_save_file = PROJECT_DIR/'bin'/'data'/'world_data.yaml'
    
    
    
    
    @render_pipeline = OIT_RenderPipeline.new
    
    # want these created once, and not reloaded when code is reloaded.
    # @environment is reloaded with reloading of new code,
    # then it can clobber the positions loaded by @frame_history
    # (or maybe we can reload @environment in on_reload, BEFORE @frame_history)
    
    # 
    # OpenEXR animation texture test
    # 
    
    data_dir = (PROJECT_DIR/'bin'/'data')
    geometry_texture_dir = data_dir/'geom_textures'
    
    @environment = VertexAnimationBatch.new(
      geometry_texture_dir/"animation.position.exr",
      geometry_texture_dir/"animation.normal.exr",
      geometry_texture_dir/"animation.transform.exr"
    )
    
    @frame_history = FrameHistory.new(self)
    
    @entity_name_to_id = Hash.new
    @entity_name_to_id['CharacterTest'] = 74
  end
  
  # run when exception is detected
  def on_crash
    puts "core: on_crash"
    @crash_detected = true
    
    @frame_history.pause
    @frame_history.update
    @frame_history.step_back
    @frame_history.update
    
    
    # self.ensure()
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
    
    
    # save_world_state()
    
    # FileUtils.rm @world_save_file if @world_save_file.exist?
  end
  
  
  def on_reload
    puts "core: on reload"
    
    # if !@crash_detected
      # on a successful reload after a normal run with no errors,
      # need to free resources from the previous normal run,
      # because those resources will be initialized again in #setup
      self.ensure()
      
      # Save world on successful reload without crash,
      # to prevent discontinuities. Otherwise, you would
      # need to manually refresh the Blender viewport
      # just to see the same state that you had before reload.
      # save_world_state()
    # end
    
    @crash_detected = false
    
    @update_scheduler = nil
    
    # setup()
      # @message_history = History.new
      # @depsgraph = DependencyGraph.new
      
      # puts "clearing"
      # @depsgraph.clear
      
      # puts "reloading history"
      # @message_history.on_reload
      
      puts "start up sync"
      @sync = BlenderSync.new(@w, @depsgraph, @message_history, self)
      # (need to re-start sync, because the IO thread is stopped in the ensure callback)
      
      
      if @frame_history.time_traveling?
        # @frame_history = @frame_history.branch_history
        
        # For now, just replace the curret timeline with the alt one.
        # In future commits, we can refine this system to use multiple
        # timelines, with UI to compress timelines or switch between them.
        
        
        
        @frame_history.branch_history
        
      else
        # was paused when the crash happened,
        # so should be able to 'play' and resume execution
        @frame_history.play
        puts "frame: #{@frame_history.frame_index}"
      end
    
    
    
    
    @first_update = true
    puts "reload complete"
    
    
    # load_world_state()
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
    
    # obj['view_perspective'] # [PERSP', 'ORTHO', 'CAMERA']
    # ('CAMERA' not yet supported)
    # ('ORTHO' support currently rather poor)
    
    # RubyProf.start
    
    dump_yaml @depsgraph => @world_save_file
    puts "world saved!"
  end
  
  def load_world_state
    if @world_save_file.exist?
      puts "loading 3D graphics data..."
      
      # 
      # loading the file takes 17 - 35 ms.
      # the entire loading update takes ~1800 ms
      # so the file IO is negligible
      # 
      
      # t0 = RubyOF::Utils.ofGetElapsedTimeMicros
      # File.readlines(@world_save_file)
      # t1 = RubyOF::Utils.ofGetElapsedTimeMicros
      # dt = t1-t0
      # puts "file load time: #{dt / 1000} ms"
      
      @sync.stop
      
      @depsgraph = YAML.load_file @world_save_file
      
      @sync = BlenderSync.new(@w, @depsgraph) # relink with @depsgraph
      puts "load complete!"
      
      # result = RubyProf.stop
      
      # printer = RubyProf::FlatPrinter.new(result)
      # printer.print(STDOUT)
      
      # printer = RubyProf::CallStackPrinter.new(result)
      
      # File.open((PROJECT_DIR/'profiler.html'), 'w') do |f|
      #   printer.print(f)
      # end
    end
  end
  
  
  # use a structure where Fiber does not need to be regenerated on reload
  def update
    @crash_detected = false # reset when normal updates are called again
    
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
      # load_world_state
      
      @first_update = false
      
      
      # # 
      # # jpg test
      # # 
      
      # @pixels = RubyOF::Pixels.new
      # ofLoadImage(@pixels, "/home/ravenskrag/Desktop/gem_structure/bin/projects/blender_iso_game/bin/data/hsb-cone.jpg")
      
      # @texture_out = RubyOF::Texture.new
      
      # @texture_out.wrap_mode(:vertical => :clamp_to_edge,
      #                      :horizontal => :clamp_to_edge)
      
      # @texture_out.filter_mode(:min => :nearest, :mag => :nearest)
      
      # @texture_out.load_data(@pixels)
      
      
      
      
      
    end
    
    
    
    @sync.update
    
    
    @frame_history.update
    
  end
  
  
  
  
  # methods #update and #draw are called by the C++ render loop
  # Their only job now at the Ruby level is to set up Fibers
  # which call the true render logic. This structure is necessary
  # to allow for live loading - if the update / draw logic
  # is directly inside the Fiber, there's no good way to reload it
  # when the file reloads.
  def on_update(snapshot)
    # step every x frames
    
    x = 8
    
    
    moves = [
      GLM::Vec3.new(1, 0, 0),
      GLM::Vec3.new(1, 0, 0),
      GLM::Vec3.new(0, 1, 0),
      GLM::Vec3.new(0, 1, 0),
      GLM::Vec3.new(0, 1, 0),
      GLM::Vec3.new(0, 1, 0),
      GLM::Vec3.new(-1, 0, 0),
      GLM::Vec3.new(-1, 0, 0),
      GLM::Vec3.new(0, 1, 0),
    ]
    
    
    # TODO: wrap GLM::Vec3 multiply by a scalar
    # TODO: how can I step this execution forward frame-by-frame using Blender's UI?
    # TODO: how can I step execution back?
    # TODO: how can I jump to an arbitrary point in execution?
    
    x.times do 
      snapshot.frame do
        # NO-OP
      end
    end
    
    moves.each do |v|
      # step in a direction, but subdivide into
      # two motions for animation / tweening
      2.times do
        # must exit the mutate block to set the value back
        
        
        snapshot.frame do
          i = @entity_name_to_id['CharacterTest']
          i = 74
          @environment.mutate_entity_transform(i) do |mat|
            v2 = GLM::Vec3.new(v.x*0.5, v.y*0.5, v.z*0.5)
            
            GLM.translate(mat, v2)
          end
          
          
        end
        
        x.times do 
          snapshot.frame do
            # NO-OP
          end
        end
        
        # if v.x == -1
        #   raise "error test"
        # end
      end
    end
    
  end
  
  
  def snapshot_gamestate
    # for now, just save the state of the one entity that's moving
    i = @entity_name_to_id['CharacterTest']
    return @environment.get_entity_transform(i)
  end
  
  def load_state(state)
    i = @entity_name_to_id['CharacterTest']
    @environment.set_entity_transform(i, state)
  end
  
  
  def update_while_crashed
    @crash_detected = true # set in Core#on_crash
    
    # puts "=== update while crashed ==="
    
    # pass @crash_detected flag to FrameHistory
    @frame_history.crash_detected
    
    # update messages and history as necessary to try dealing with crash
    @sync.update
    @frame_history.update
      # FrameHistory will clear the @crash_detected state
      # if you start to go back in time after a crash.
      
      
      # oh wait,
      # but need take one step back when crash is detected
    
    # If FrameHistory was able to use time travel to resolve the crash
    # then clear the flag
    if !@frame_history.crash_detected?
      @crash_detected = false
    end
    
    # puts "=== update while crashed END"
  end
  
  
  # Propagates signal from FrameHistory back up to LiveCode
  # that the problem which caused the crash has been managed,
  # even without loading new code.
  def in_error_state?
    @crash_detected
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
  
  
  def load_anim_textures(message)
    p message
    @environment = VertexAnimationBatch.new(
      message['position_tex_path'],
      message['normal_tex_path'],
      message['transform_tex_path'],
    )
  end
  
  def update_entity_mapping(message)
    p message['value']
    @entity_name_to_id = message['value']
  end
  
  
  include RubyOF::Graphics
  def on_draw
    
    # 
    # setup materials, etc
    # 
    # if @first_draw
      
    #   @first_draw = false
      
    # end
    
    
    
    
    # 
    # set up phases of drawing
    # 
    
    @render_pipeline.draw(@w, lights:@depsgraph.lights,
                              camera:@depsgraph.viewport_camera) do |pipeline|
      pipeline.opaque_pass do
        @environment.draw_scene
        
        
        # glCullFace(GL_BACK)
        # glDisable(GL_CULL_FACE)
      end
      
      pipeline.transparent_pass do
        
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
        
        
        # line_height = 35
        # p3 = CP::Vec2.new(500,650)
        # str_out = []
        
        # batches = @depsgraph.batches
        # header = [
        #   "i".rjust(3),
        #   "mesh".ljust(10), # BlenderMeshData
          
        #   "mat".ljust(15), # BlenderMaterial
        #   # ^ use #inspect to visualize empty string
          
        #   "batch size" # RenderBatch
          
        # ].join('| ')
        
        # str_out = 
        #   batches.each_with_index.collect do |batch_line, i|
        #     a,b,c = batch_line
        #     # data = [
        #     #   a.class.to_s.each_char.first(20).join(''),
        #     #   b.class.to_s.each_char.first(20).join(''),
        #     #   c.class.to_s.each_char.first(20).join('')
        #     # ].join(', ')
            
            
        #     data = [
        #       "#{i}".rjust(3),
        #       a.name.ljust(10), # BlenderMeshData
              
        #       b.name.inspect.ljust(15), # BlenderMaterial
        #       # ^ use #inspect to visualize empty string
              
        #       c.size.to_s # RenderBatch
              
        #     ].join('| ')
        #   end
        
        # ([header] + str_out).each_with_index do |line, i|
        #   @fonts[:monospace].draw_string(line, p3.x, p3.y+line_height*i)
        # end
        
        
        
        # t1 = RubyOF::TimeCounter.now
        # puts "=> UI    : #{(t1 - t0).to_ms} ms"
        
        
        # @texture_out.draw_wh(500,50,0, @pixels.width, @pixels.height)
        @environment.draw_ui
        
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
            ofDrawRectangle(0,0,0, @w.width, @w.height)
          ofPopStyle()
        end
      end
    end
    
    
    # @depsgraph.draw(@w) do
    
      
      
    # end
    
    
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


  
  
