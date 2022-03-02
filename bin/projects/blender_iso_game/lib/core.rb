
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


load LIB_DIR/'oit_render_pipeline.rb'

load LIB_DIR/'world.rb'
load LIB_DIR/'frame_history.rb'









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
    
    
    
    
    
    
    @world_save_file = PROJECT_DIR/'bin'/'data'/'world_data.yaml'
    
    
    
    
    @render_pipeline = OIT_RenderPipeline.new
    
    # want these created once, and not reloaded when code is reloaded.
    # @world is reloaded with reloading of new code,
    # then it can clobber the positions loaded by @frame_history
    # (or maybe we can reload @world in on_reload, BEFORE @frame_history)
    
    # 
    # OpenEXR animation texture test
    # 
    
    data_dir = (PROJECT_DIR/'bin'/'data')
    geometry_texture_dir = data_dir/'geom_textures'
    
    @world = World.new(
      geometry_texture_dir/"animation.position.exr",
      geometry_texture_dir/"animation.normal.exr",
      geometry_texture_dir/"animation.transform.exr"
    )
    
    @frame_history = FrameHistory.new(self)
    
    
    @world.data.each.each_with_index do |entity, i|
      puts "#{i.to_s.rjust(4)} : #{entity.inspect}"
    end
    
    
    
    
    
    
    @message_history = BlenderHistory.new
    @depsgraph = DependencyGraph.new
    @sync = BlenderSync.new(@message_history, @frame_history)
    
  end
  
  # run when exception is detected
  def on_crash
    puts "core: on_crash"
    @crash_detected = true
    
    @frame_history.pause
    @frame_history.update
    @frame_history.step_back
    @frame_history.update
    
    
    
    # Don't stop sync thread on crash.
    # Need to be able to communicate with Blender
    # in order to control time travel
    
    # self.ensure()
  end
  
  # run on normal exit, before exiting program
  def on_exit
    puts "core: on exit"
    
    # if @crash_detected
      self.ensure()
    # end
    
    
    # puts @draw_durations.join("\t")
    if RB_SPIKE_PROFILER.enabled?
      RB_SPIKE_PROFILER.disable
    end
    
    
    # save_world_state()
    
    # FileUtils.rm @world_save_file if @world_save_file.exist?
  end
  
  
  def on_reload
    puts "core: on_reload() BEGIN"
    
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
      
      puts "restart sync"
      @sync.reload
      # (need to re-start sync, because the IO thread is stopped in the ensure callback)
      
      
      if @frame_history.time_traveling?
        # @frame_history = @frame_history.branch_history
        
        # For now, just replace the curret timeline with the alt one.
        # In future commits, we can refine this system to use multiple
        # timelines, with UI to compress timelines or switch between them.
        
        
        
        @frame_history.branch_history
        
      else
        # # was paused when the crash happened,
        # # so should be able to 'play' and resume execution
        # @frame_history.play
        # puts "frame: #{@frame_history.frame_index}"
      end
      
    
    
    
    
    @first_update = true
    puts "core: on_reload() END"
    
    
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
    
    # TODO: seems like the thread is ending, but the FIFO file is left standing. Need to at least close the file from the reader side, even if the actual named pipe "file" is left standing.
      # If the named pipe is closed, subsequent writes should recieve the SIGPIPE signal (broken pipe) which should allow me to deal with hanging stuff from Blender
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
      # load_world_state()
      
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
    
    
    
    @sync.update do |message|
      parse_blender_data message
    end
    
    
    @frame_history.update # => on_update
    
    @world.update
  end
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  # TODO: somehow consolidate setting of dirty flag for all entity types
  def parse_blender_data(message)
    # t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # data = {
    #     'timestamps' : {
    #         'start_time': total_t0,
    #         'end_time':   total_t1
    #     },
        
    #     'all_entity_names' : object_list,
        
    #     'datablocks' : datablock_export,
    #     'objects' : obj_export
    # }
    
    
    # Temporary storage for Blender backend datablocks, like mesh data,
    # before they become attached to an entity.
    @new_datablocks ||= Hash.new
    
    # depsgraph only stores materials that are associated with a batch, so we need to temporarily store materials here as they are loaded
    @new_materials ||= Hash.new
    
    
    # NOTE: current implementation puts state in @new_datablocks and @new_materials that will be tricky on reload / rewind. need to better handle this state
    
    
    
    # p @depsgraph.instance_variable_get("@mesh_objects")
    # p @new_datablocks
    # puts "--- #{message['type']} ---"
    # puts message['type'] === 'bpy.types.Mesh'
    
    
    case message['type']
    when 'all_entity_names'
      # The viewport camera is an object in RubyOF, but not in Blender
      # Need to remove it from the entity list or the camera
      # will be deleted.
      @depsgraph.gc(active: message['list'])
      
    when 'viewport_camera'
      # sent on viewport update, not every frame
      # puts "update viewport"
      
      @depsgraph.viewport_camera.tap do |camera|
        camera.dirty = true
        
        camera.load(message)
      end
      
    when 'viewport_region'
      # sent on some updates, when window link enabled
      # puts "viewport_region"
      # p blender_data
      # p blender_data.keys
      
      # 
      # sync window size
      # 
      
      w = message['width']
      h = message['height']
      @window.set_window_shape(w,h)
      
      # @camera.aspectRatio = w.to_f/h.to_f
      
      
      # 
      # sync window position
      # (assuming running on Linux)
      # - trying to match pid_query with pid_hit
      # 
      
      # puts "trying to sync"
      sync_window_position(blender_pid: message['pid'])
      
    when 'material_mapping'
      
      # NO LONGER NECESSARY
      # materials are exported to OpenEXR transform texture in python
      # the RubyOF renderer just needs to render the data provided.
      
    when 'bpy.types.Material'
      # (same pattern as mesh datablock manipulation)
      # retrieve existing material and edit its properties
      
      # NO LONGER NECESSARY
      # python code now exports this data in a denormalized way,
      # encoding it on the transform texture
      
      
      
      # TODO: create Ruby API to edit material settings of object in transform texture, so that code can dynamically edit these properties in game
      
    when 'bpy.types.Light'
      # # I don't want to have linked lights in RubyOF.
      # # Thus, rather than create light datablocks here,
      # # link the deserialized JSON message into the object 'data' field
      # # so it all can be unpacked together in a later phase
      
      # blender_data['objects']&.tap do |object_list|
        
      #   object_list
      #   .select{|o| o['type'] == 'LIGHT' }
      #   .find{  |o| o['name'] == data['light_name'] }
      #   .tap{   |o| o['data'] = data }
      #   # links data even if data field is already set
      #   # (the data stored in history seems to already be linked, but I'm not sure how that happens)
        
      # end
      
    when 'bpy_types.Mesh'
      # create underlying mesh data (verts)
      # to later associate with mesh objects (transform)
      # which sets the foundation for instanced geometry
      
      
      # NO LONGER NECESSARY
      # replaced by the OpenEXR export
      
    when 'bpy_types.Object'
      case message['.type']
      when 'MESH'
        # update object transform based on direct manipulation in blender
        @core.update_entity(message)
        
      when 'LIGHT'
        # load transform AND data for lights here as necessary
        # ('data' field has already been linked to necessary data)
        
        # puts "loading light: #{message['name']}"
        
        light =
          @depsgraph.fetch_light(message['name']) do |name|
            BlenderLight.new(name).tap do |light|
              @depsgraph.add light
            end
          end
        
        message['transform']&.tap do |transform_data|
          light.load_transform(transform_data)
        end
        
        message.tap do |core_data|
          # puts ">> light data"
          # p core_data
          light.load_data(core_data)
        end
        
      end
      
    
    
    when 'timeline_command'
      # p message
      parse_timeline_commands(message)
    
    when 'update_anim_json'
      update_animation_json(message['value'])
      
      # @core.update_entity_mapping(message)
      # @core.update_mesh_mapping(message)
    
    when 'update_anim_textures', 'update_geometry', 'update_transform', 'update_material'
      
      self.send(message['type'], message)
    
    else
      
      
    end
    
    
    # # ASSUME: if an object's 'data' field is set, then the linkage to unedrlying data has changed. If the field is not set, then no change.
    
    
    # # t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # # dt = t1-t0;
    # # puts "time - parse data: #{dt} us"
    
  end
  
  
  
  def parse_timeline_commands(message)
    case message['name']
    when 'reset'
      # # blender has reset, so reset all RubyOF data
      # @depsgraph.clear
      
      puts "== reset"
      
      @sync.reset
      
      if @frame_history.time_traveling?
        # For now, just replace the curret timeline with the alt one.
        # In future commits, we can refine this system to use multiple
        # timelines, with UI to compress timelines or switch between them.
        
        puts "loopback reset"
        
        @frame_history.branch_history
        
        
        message = {
          'type' => 'loopback_reset',
          'history.length'      => @frame_history.length,
          'history.frame_index' => @frame_history.frame_index
        }
        
        @sync.send_to_blender message
        
      else
        puts "(reset else)"
      end
      
      puts "====="
      
    when 'pause'
      puts "== pause"
      p @frame_history.state
      
      if @frame_history.state == :generating_new
        @frame_history.pause
        
        
        message = {
          'type' => 'loopback_paused_new',
          'history.length'      => @frame_history.length,
          'history.frame_index' => @frame_history.frame_index
        }
        
        @sync.send_to_blender message
        
      else
        @frame_history.pause
        
        message = {
          'type' => 'loopback_paused_old',
          'history.length'      => @frame_history.length,
          'history.frame_index' => @frame_history.frame_index
        }
        
        @sync.send_to_blender message
        
      end
      
      puts "====="
      
      
    when 'play'
      puts "== play"
      p @frame_history.state
      
      
      @frame_history.play # stubbed for some states
      
      if @frame_history.state == :finished
        @frame_history.play 
        
        message = {
          'type' => 'loopback_play+finished',
          'history.length' => @frame_history.length
        }
        
        @sync.send_to_blender message
      end
      
      # if @frame_history.state != :generating_new
      #   # ^ this will not immediately advance
      #   #   to the new state. It's more like shifting
      #   #   from Park to Drive.
      #   #   Transition to next state will not happen until
      #   #   FrameHistory#update -> State#update
      #   # 
      #   # note: even responding to pause
      #   # takes at least 1 frame. need a better way
      #   # of dealing with this.
      #   # 
      #   # For now, I will expand the play range when python
      #   # detects playback has started, without waiting
      #   # for a round-trip response from ruby.
      #   # (using aribtrary large number, 1000 frames)
      #   # 
      #   # TODO: use the "preview range" feature to set
      #   #       two time ranges for the timeline
      #   #       1) the maximum number of frames that can 
      #   #          be stored
      #   #       2) the current number of frames in history
        
      #   if @frame_history.play == :generating_new
      #     message = {
      #       'type' => 'loopback_play',
      #       'history.length' => @frame_history.length
      #     }
          
      #     @blender_link.send message
      #   end
      # end
      
      puts "====="
      
    
    when 'seek'
      @frame_history.seek(message['time'])
      
    end
  end
  
  
  
  
  # 
  # handle update messages from BlenderSync
  # 
  
  def update_animation_json(json_filepath)
    p json_filepath
    raise "ERROR: Not yet implemented"
    # TODO: implement this
  end
  
  
  
  # Update both transform texture and vertex textures.
  # Used when you do a full export of everything,
  # similar to running a "clean build" in C/C++.
  def update_anim_textures(message)
    # p message
    @world.load_transform_texture(message['transform_tex_path'])
    @world.load_vertex_textures(message['position_tex_path'],
                                      message['normal_tex_path'])
    
    
    # reload history
    # (code adapted from Core#on_reload)
    if @frame_history.time_traveling?
      # @frame_history = @frame_history.branch_history
      
      # For now, just replace the curret timeline with the alt one.
      # In future commits, we can refine this system to use multiple
      # timelines, with UI to compress timelines or switch between them.
      
      
      
      @frame_history.branch_history
      
    else
      # Do NOT trigger play on reload after direct manipulation.
      
      # # was paused when the crash happened,
      # # so should be able to 'play' and resume execution
      # @frame_history.play
      # puts "frame: #{@frame_history.frame_index}"
    end
  end
  
  # vertex position and normal data for one or more meshes has been updated
  def update_geometry(message)
    p message
    # @world.load_transform_texture(message['transform_tex_path'])
    @world.load_vertex_textures(message['position_tex_path'],
                                      message['normal_tex_path'])
    
  end
  
  # transform data for a entity has been updated
  # (may or may not contain an armature)
  def update_transform(message)
    puts "update transform"
    p message
    @world.load_transform_texture(message['transform_tex_path'])
    # @world.load_vertex_textures(message['position_tex_path'],
    #                                   message['normal_tex_path'])
    
  end
  
  
  # material data is stored in the transform texture
  # (like material property block)
  # updates to a single material may effect one object, or many,
  # so easiest just to load the entire transform texture again
  def update_material(message)
    p message
    @world.load_transform_texture(message['transform_tex_path'])
  end
  
  
  def update_entity(message)
    # case message['.type']
    # when 'MESH'
    #   name = message['name']
    #   id = @entity_name_to_id[name]
      
      
    #   nested_array = message['transform']
    #   # ^ array of arrays
      
    #   # p nested_array
      
    #   @world.set_entity_transform_array id, nested_array
    #   # ^ thin wrapper on C++ callback
      
      
      
    #   # reload history
    #   # (code adapted from Core#on_reload)
    #   if @frame_history.time_traveling?
    #     # @frame_history = @frame_history.branch_history
        
    #     # For now, just replace the curret timeline with the alt one.
    #     # In future commits, we can refine this system to use multiple
    #     # timelines, with UI to compress timelines or switch between them.
        
        
        
    #     @frame_history.branch_history
        
    #   else
    #     # Do NOT trigger play on reload after direct manipulation.
    #     # Need the user to press "play" manually to signal
    #     # they are done with direct manipulation. Otherwise,
    #     # inputs from direct manipulation are comingled with
    #     # inputs from ruby code execution.
        
        
    #     # # was paused when the crash happened,
    #     # # so should be able to 'play' and resume execution
    #     # @frame_history.play
    #     # puts "frame: #{@frame_history.frame_index}"
    #   end
    # else
      
      
    # end
  end
  
  
  
  
  
  
  
  def sync_window_position(blender_pid: nil)
    # tested on Ubuntu 20.04.1 LTS
    # will almost certainly work on all Linux distros with X11
    # maybe will work on OSX as well...? not sure
    # (xwininfo and xprop should be standard on all systems with X11)
    
    # if @pid_query != pid
      # @pid_query = pid
      blender_pos = find_window_position("Blender",   blender_pid)
      rubyof_pos  = find_window_position("RubyOF blender integration", Process.pid)
      
      
      # 
      # measure the delta
      # 
      
      delta = blender_pos - rubyof_pos
      puts "current window offset: #{blender_pos - rubyof_pos}"
      
      # measurements of manually positioned windows:
      # dx = 0 to 3  (unsure of exact value)
      # dy = -101    (strange number, but there it is)
      
      
      # 
      # apply the delta
      # 
      
      # just need to apply inverse of the measured delta to RubyOF windows
      delta = CP::Vec2.new(-107,-151)*-1
      @window.position = (blender_pos + delta).to_glm
      
      # NOTE: system can't apply the correct delta if Blender is flush to the left side of the screen. In that case, dx = -8 rather than 0 or 3. Otherwise, this works fine.
      
      
      
      
      # puts "my pid: #{Process.pid}"
    # end
  end
  
  def find_window_position(query_title_string, query_pid)
    # puts "trying to sync window position ---"
    
    
    # 
    # find the wm id given PID
    # 
    
    wm_ids = 
      `xwininfo -root -tree | grep '#{query_title_string}'`.each_line
      .collect{ |line|
        # 0x6e00002 "Blender* [/home/...]": ("Blender" "Blender")  2544x1303+0+0  +206+95
        line.split.first
      }
    
    pids = 
      wm_ids.collect{ |wm_id|
        # _NET_WM_PID(CARDINAL) = 1353883
        `xprop -id #{wm_id} | grep PID`.split.last
      }
      .collect{ |id_string|  id_string.to_i }
    
    hit_wm_id = pids.zip(wm_ids).assoc(query_pid).last
    # puts "wm_id: #{hit_wm_id}"
    
    
    # 
    # use wm id to find window geometry (size and position)
    # 
    
    window_info = `xwininfo -id #{hit_wm_id}`
    window_info = 
      window_info.each_line.to_a
      .map{ |line|   line.strip  }
      .map{ |l| l == "" ? nil : l  } # replace empty lines with nil
      .compact                       # remove all nil entries from array
    # p window_info
    
    info_hash = 
      window_info[1..-2] # skip first line (title) and last (full geometry)
      .map{  |line|
        line.split(':')    # colon separator
        .map{|x| x.strip } # remove leading / trailing whitespace
      }.to_h
    # p info_hash
    
    hit_px = info_hash['Absolute upper-left X'].to_i
    hit_py = info_hash['Absolute upper-left Y'].to_i
    
    
    # puts "-------"
    
    return CP::Vec2.new(hit_px, hit_py)
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
      GLM::Vec3.new(0, 1, 0),
      GLM::Vec3.new(0, 1, 0),
      GLM::Vec3.new(0, 1, 0),
      GLM::Vec3.new(0, 1, 0),
      GLM::Vec3.new(-1, 0, 0),
      GLM::Vec3.new(-1, 0, 0),
      GLM::Vec3.new(0, 1, 0),
    ]
    
    
    # TODO: wrap GLM::Vec3 multiply by a scalar
    
    moves.each_with_index do |v, move_idx|
      # step in a direction, but subdivide into
      # two motions for animation / tweening
      
      puts "move idx: #{move_idx} of #{moves.length-1}"
      
      
      
      # distribute the moves over a series of turns.
      # each turn, take one movement action.
      # + move in the specified way
      # + play an animation to interpolate the frames
      
      # dt = 0.5
      
      
      
      #  0 - log root position
      snapshot.frame do
        
      end
      
      
      # transform could be set on frame 0 (e.g. the very first frame)
      # so want to load the transform data after that
      
      # all code inside snapshot blocks will be skipped on resume
      # so any code related to a branch condition
      # needs to be outside of the snapshot blocks.
      
      entity = @world.data.find_entity_by_name('CharacterTest')
      p entity
      
      pos = entity.position
      puts "grid position: #{pos}"
      
      
      # step up if there's an obstruction
      if @world.space.point_query(pos + v).include? 'Cube.002' # datablock name
        GLM::Vec3.new(0,0,1).tap do |v|
          #  1 - animate
          snapshot.frame do
            puts pos
          end
          #  2 - animate
          snapshot.frame do
            
          end
          #  3 - animate
          snapshot.frame do
            
          end
          #  4 - animate
          snapshot.frame do
            
          end
          #  5 - animate
          snapshot.frame do
            
          end
          #  6 - animate
          snapshot.frame do
            
          end
          #  7 - animate
          snapshot.frame do
            
          end
          #  8 - animate (halfway)
          snapshot.frame do
            # v2 = GLM::Vec3.new(v.x, v.y, v.z)*dt
            # entity.position = pos + v2
          end
          #  9 - animate
          snapshot.frame do
            
          end
          # 10 - animate
          snapshot.frame do
            
          end
          # 11 - animate
          snapshot.frame do
            
          end
          # 12 - animate
          snapshot.frame do
            
          end
          # 13 - animate
          snapshot.frame do
            
          end
          # 14 - animate
          snapshot.frame do
            
          end
          # 15 - animate
          snapshot.frame do
            
          end
          # 16 - animate
          snapshot.frame do
            
          end
          # 17 - animate
          snapshot.frame do
            v2 = GLM::Vec3.new(v.x, v.y, v.z)
            entity.position = pos + v2
          end
          
          
          #  0 - new root position
          snapshot.frame do
            
          end
          
          # 
          # update pos = new root position
          # 
          pos = entity.position
        end
        
      end
      
      
      #  1 - animate
      snapshot.frame do
        p pos
      end
      #  2 - animate
      snapshot.frame do
        
      end
      #  3 - animate
      snapshot.frame do
        
      end
      #  4 - animate
      snapshot.frame do
        
      end
      #  5 - animate
      snapshot.frame do
        
      end
      #  6 - animate
      snapshot.frame do
        
      end
      #  7 - animate
      snapshot.frame do
        
      end
      #  8 - animate (halfway)
      snapshot.frame do
        # v2 = GLM::Vec3.new(v.x, v.y, v.z)*dt
        # entity.position = pos + v2
      end
      #  9 - animate
      snapshot.frame do
        
      end
      # 10 - animate
      snapshot.frame do
        
      end
      # 11 - animate
      snapshot.frame do
        
      end
      # 12 - animate
      snapshot.frame do
        
      end
      # 13 - animate
      snapshot.frame do
        
      end
      # 14 - animate
      snapshot.frame do
        
      end
      # 15 - animate
      snapshot.frame do
        
      end
      # 16 - animate
      snapshot.frame do
        
      end
      # 17 - animate
      snapshot.frame do
        v2 = GLM::Vec3.new(v.x, v.y, v.z)
        entity.position = pos + v2
      end
      # # 18 - new root position
      # snapshot.frame do
        
      # end
      
    end
    
  end
  
  
  
  # 
  # methods used by FrameHistory to save world state
  # 
  def snapshot_gamestate
    # for now, just save the state of the one entity that's moving
    entity = @world.data.find_entity_by_name('CharacterTest')
    return entity.transform_matrix
  end
  
  def load_state(state)
    entity = @world.data.find_entity_by_name('CharacterTest')
    entity.transform_matrix = state
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
    
    @render_pipeline.draw(@window, lights:@depsgraph.lights,
                              camera:@depsgraph.viewport_camera) do |pipeline|
      pipeline.opaque_pass do
        @world.draw_scene
        
        
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
        
        
        
        @fonts[:monospace].draw_string("frame #{@frame_history.frame_index}/#{@frame_history.length-1}",
                                         1178, 846+40)
        
        @fonts[:monospace].draw_string("state #{@frame_history.state}",
                                         1178, 846)
        
        # @fonts[:monospace].draw_string("history size: #{}",
                                         # 400, 160)
        
        
        # t1 = RubyOF::TimeCounter.now
        # puts "=> UI    : #{(t1 - t0).to_ms} ms"
        
        
        # @texture_out.draw_wh(500,50,0, @pixels.width, @pixels.height)
        @world.draw_ui
        
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
    
    
    # @depsgraph.draw(@window) do
    
      
      
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


  
  
