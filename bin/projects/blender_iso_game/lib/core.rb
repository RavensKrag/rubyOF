
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


class VertexAnimationBatch
  include RubyOF::Graphics
  
  def initialize(position_tex_path, normal_tex_path, transform_tex_path)
    @pixels = {
      :positions  => RubyOF::FloatPixels.new,
      :normals    => RubyOF::FloatPixels.new,
      :transforms => RubyOF::FloatPixels.new
    }
    
    @textures = {
      :positions  => RubyOF::Texture.new,
      :normals    => RubyOF::Texture.new,
      :transforms => RubyOF::Texture.new
    }
    
    ofLoadImage(@pixels[:positions],  position_tex_path)
    ofLoadImage(@pixels[:normals],    normal_tex_path)
    ofLoadImage(@pixels[:transforms], transform_tex_path)
    
    # 
    # configure all sets of pixels (CPU data) and textures (GPU data)
    # 
    @pixels.values.zip(@textures.values).each do |pixels, texture|
      # y axis is flipped relative to Blender???
      # openframeworks uses 0,0 top left, y+ down
      # blender uses 0,0 bottom left, y+ up
      pixels.flip_vertical
      
      puts pixels.color_at(0,2)
      
      texture.disableMipmap() # resets min mag filter
      
      texture.wrap_mode(:vertical => :clamp_to_edge,
                           :horizontal => :clamp_to_edge)
      
      texture.filter_mode(:min => :nearest, :mag => :nearest)
      
      texture.load_data(pixels)
    end
    
    # 
    # Create a mesh consiting of a line of unconnected triangles
    # the verticies in this mesh will be transformed by the textures
    # so it doesn't matter what their exact positons are.
    # 
    @mesh = RubyOF::VboMesh.new
    
    @mesh.setMode(:triangles)
    # ^ TODO: maybe change ruby interface to mode= or similar?
    
    num_verts = @textures[:positions].width.to_i
    num_tris = num_verts / 3
    
    size = 1 # useful when prototyping to increase this for visualization
    num_tris.times do |i|
      a = i*3+0
      b = i*3+1
      c = i*3+2
      # DEBUG PRINT: show indicies assigned to tris an verts
      # p [i, [a,b,c]]
      
      
      # UV coordinates specified in pixel indicies
      # will offset by half a pixel in the shader
      # to sample at the center of each pixel
      
      @mesh.addVertex(GLM::Vec3.new(size*i,0,0))
      @mesh.addTexCoord(GLM::Vec2.new(a, 0))
      
      @mesh.addVertex(GLM::Vec3.new(size*i+size,0,0))
      @mesh.addTexCoord(GLM::Vec2.new(b, 0))
      
      @mesh.addVertex(GLM::Vec3.new(size*i,size,0))
      @mesh.addTexCoord(GLM::Vec2.new(c, 0))
      
    end
    
    
    # 
    # material invokes shaders
    # 
    @mat = BlenderMaterial.new "OpenEXR vertex animation mat"
    
    shader_src_dir = PROJECT_DIR/"bin/glsl"
    @vert_shader_path = shader_src_dir/"animation_texture.vert"
    # @frag_shader_path = shader_src_dir/"phong_test.frag"
    @frag_shader_path = shader_src_dir/"phong.frag"
    
    
    # @mat.diffuse_color = RubyOF::FloatColor.rgba([1,1,1,1])
    # @mat.specular_color = RubyOF::FloatColor.rgba([0,0,0,0])
    # @mat.emissive_color = RubyOF::FloatColor.rgba([0,0,0,0])
    # @mat.ambient_color = RubyOF::FloatColor.rgba([0.2,0.2,0.2,0])
  end
  
  def draw_scene
    @mat.load_shaders(@vert_shader_path, @frag_shader_path) do
      # on reload
      
    end
    
    # set uniforms
    @mat.setCustomUniformTexture(
      "vert_pos_tex",  @textures[:positions], 1
    )
    
    @mat.setCustomUniformTexture(
      "vert_norm_tex", @textures[:normals], 2
    )
    
    @mat.setCustomUniformTexture(
      "object_transform_tex", @textures[:transforms], 3
    )
      # but how is the primary texture used to color the mesh in the fragment shader bound? there is some texture being set to 'tex0' but I'm unsure where in the code that is actually specified
    
    # 
    # draw all the instances using one draw call
    # number of instances is the height of the transform texture - 1
    # (one row is just a human-readable visual marker - it is not data)
    # 
    using_material @mat do
      @mesh.draw_instanced(@pixels[:transforms].height-1)
    end
  end
  
  def draw_ui
    @textures[:positions].tap do |texture| 
      texture.draw_wh(500,50,0, texture.width, -texture.height)
    end
    
    
    @node ||= RubyOF::Node.new
    @node.scale    = GLM::Vec3.new(15, 15, 1)
    @node.position = GLM::Vec3.new(500, 400, 1)
    
    @node.transformGL
    
      @textures[:transforms].tap do |texture| 
        texture.draw_wh(0,0,0, texture.width, -texture.height)
      end
      
    @node.restoreTransformGL
  end
  
  
  def get_entity_transform(i)
    # pull colors out of image on CPU side
    # similar to how the shader pulls data out on the GPU side
    
    v1 = @pixels[:transforms].color_at(1, i)
    v2 = @pixels[:transforms].color_at(2, i)
    v3 = @pixels[:transforms].color_at(3, i)
    v4 = @pixels[:transforms].color_at(4, i)
    
    mat = GLM::Mat4.new(GLM::Vec4.new(v1.r, v2.r, v3.r, v4.r),
                        GLM::Vec4.new(v1.g, v2.g, v3.g, v4.g),
                        GLM::Vec4.new(v1.b, v2.b, v3.b, v4.b),
                        GLM::Vec4.new(v1.a, v2.a, v3.a, v4.a));
    
    return mat
  end
  
  def set_entity_transform(i, mat)
    
    # mat = GLM.translate(mat, GLM::Vec3.new(0.01, 0, 0))
    # mat = GLM.translate(mat, GLM::Vec3.new(0, 0.01, 0))
    # mat = GLM.translate(mat, GLM::Vec3.new(0, 0, 0.01))
    
    # 
    # convert mat4 transform data back to color data
    # 
    mv0 = mat[0]
    mv1 = mat[1]
    mv2 = mat[2]
    mv3 = mat[3]
    
    # v1.r = mat[0][0]
    # v1.g = mat[1][0]
    # v1.b = mat[2][0]
    # v1.a = mat[3][0]
    
    c1 = RubyOF::FloatColor.rgba([mv0[0], mv1[0], mv2[0], mv3[0]])
    c2 = RubyOF::FloatColor.rgba([mv0[1], mv1[1], mv2[1], mv3[1]])
    c3 = RubyOF::FloatColor.rgba([mv0[2], mv1[2], mv2[2], mv3[2]])
    c4 = RubyOF::FloatColor.rgba([mv0[3], mv1[3], mv2[3], mv3[3]])
    
    
    # 
    # write colors on the CPU
    # 
    v1 = @pixels[:transforms].setColor(1, i, c1)
    v2 = @pixels[:transforms].setColor(2, i, c2)
    v3 = @pixels[:transforms].setColor(3, i, c3)
    v4 = @pixels[:transforms].setColor(4, i, c4)
    
    # 
    # transfer color data to the GPU
    # 
    @textures[:transforms].load_data(@pixels[:transforms])
    
    
    return self
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
    
    
    
    @history = BlenderHistory.new
    @depsgraph = DependencyGraph.new
    @sync = BlenderSync.new(@w, @depsgraph, @history)
    
    
    
    
    @world_save_file = PROJECT_DIR/'bin'/'data'/'world_data.yaml'
    
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
    
    
    # save_world_state()
    
    # FileUtils.rm @world_save_file if @world_save_file.exist?
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
      # save_world_state()
    end
    
    @crash_detected = false
    
    @update_scheduler = nil
    
    # setup()
      # @history = History.new
      # @depsgraph = DependencyGraph.new
      
      puts "clearing"
      @depsgraph.clear
      
      puts "reloading history"
      @history.on_reload
      
      puts "start up sync"
      @sync = BlenderSync.new(@w, @depsgraph, @history)
      # (need to re-start sync, because the IO thread is stopped in the ensure callback)
      
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
    if @first_update
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
      
      
      # 
      # OpenEXR animation texture test
      # 
      @environment = VertexAnimationBatch.new(
        "/home/ravenskrag/Desktop/blender animation export/my_git_repo/animation.position.exr",
        "/home/ravenskrag/Desktop/blender animation export/my_git_repo/animation.normal.exr",
        "/home/ravenskrag/Desktop/blender animation export/my_git_repo/animation.transform.exr"
      )
    end
    
    scheduler.section name: "sync ", budget: msec(5.0)
      @sync.update
    
    
    scheduler.section name: "main", budget: msec(6.0)
      i = 1
    
      100.times do 
        transform = @environment.get_entity_transform(i)
        
        # v = GLM::Vec3.new(0.0, 0.0, 0.0)
        v = GLM::Vec3.new(0.01, 0.0, 0.0)
        
          transform = GLM.translate(transform, v)
        
        @environment.set_entity_transform(i, transform)
      end
      
          
      
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
    # if @first_draw
      
    #   @first_draw = false
      
    # end
    
    
    # 
    # draw the scene
    # 
    # t0 = RubyOF::TimeCounter.now
    
    @depsgraph.draw(@w) do
    
      @environment.draw_scene
      
    end
    
    
    # t1 = RubyOF::TimeCounter.now
    # puts "=> scene : #{(t1 - t0).to_ms} ms"
    
    
    # 
    # draw UI
    # 
    
    # t0 = RubyOF::TimeCounter.now
    
    
    p1 = CP::Vec2.new(500,500)
    @fonts[:monospace].draw_string("hello world!", p1.x, p1.y)
    
    
    
    p2 = CP::Vec2.new(500,600)
    if @mouse_pos
      
      @fonts[:monospace].draw_string("mouse: #{@mouse_pos.to_s}", p2.x, p2.y)
    end
    
    
    line_height = 35
    p3 = CP::Vec2.new(500,650)
    str_out = []
    
    batches = @depsgraph.batches
    header = [
      "i".rjust(3),
      "mesh".ljust(10), # BlenderMeshData
      
      "mat".ljust(15), # BlenderMaterial
      # ^ use #inspect to visualize empty string
      
      "batch size" # RenderBatch
      
    ].join('| ')
    
    str_out = 
      batches.each_with_index.collect do |batch_line, i|
        a,b,c = batch_line
        # data = [
        #   a.class.to_s.each_char.first(20).join(''),
        #   b.class.to_s.each_char.first(20).join(''),
        #   c.class.to_s.each_char.first(20).join('')
        # ].join(', ')
        
        
        data = [
          "#{i}".rjust(3),
          a.name.ljust(10), # BlenderMeshData
          
          b.name.inspect.ljust(15), # BlenderMaterial
          # ^ use #inspect to visualize empty string
          
          c.size.to_s # RenderBatch
          
        ].join('| ')
      end
    
    ([header] + str_out).each_with_index do |line, i|
      @fonts[:monospace].draw_string(line, p3.x, p3.y+line_height*i)
    end
    
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


  
  
