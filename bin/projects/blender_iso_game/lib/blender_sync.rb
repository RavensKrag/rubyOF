
class BlenderSync
  MAX_READS = 20
  
  def initialize(window, world)
    @message_history = BlenderHistory.new
    
    @window = window
    @world = world
    
    
    # two-way communication between RubyOF (ruby) and Blender (python)
    # implemented using two named pipes
    @blender_link = ActorChannel.new
    
    @blender_link.start
    
    
    @blender_link.print({
      'type' => 'first_setup'
    })
  end
  
  def stop
    puts "stopping sync"
    
    @blender_link.print({
      'type' => 'sync_stopping',
      'history.length' => @world.transport.history_length
    })
    # TODO: check blender code. what is the behavior on that end?
      # when is this method triggered?
      # what should be the response from Blender?
      # need to document / explain that here
    
    @blender_link.stop
  end
  
  def reload
    puts "BlenderSync - reload()"
    if @blender_link.stopped?
      puts "BlenderSync: reloading"
      @blender_link.start
      
      @world.on_reload_code(self)
    end
  end
  
  def update
    # update_t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    
    # @blender_link.print
    # message = @blender_link.take
    
    
    # 
    # read messages from Blender (python)
    # 
    
    while message = @blender_link.take
      # t0 = RubyOF::Utils.ofGetElapsedTimeMicros
      
      # # --- This write is only needed for debugging
      # File.open(PROJECT_DIR/'bin'/'data'/'tmp.json', 'a+') do |f|
      #   f.puts JSON.pretty_generate message
      # end
      # # ---
      
      # p list
      # t1 = RubyOF::Utils.ofGetElapsedTimeMicros
      
      # dt = t1-t0;
      # puts "time - parse json: #{dt}"
      
      # puts "=> raw message: #{message.inspect}"
      
      # send all of this data to history
      @message_history.write message
      
    end
    
    # TODO: reactivate / reimplement history so state is maintained when code reloads
    
    # TODO: merge messages in order to catch up if possible?
      # like, responding to linked window mode is slow, but if we can drop some of the older messages (they're superceeded by the newer messages anyway) then we can maybe stop the framerate from tanking.
    
    # TODO: why can't the viewport be made about 1/4 of my screen size? why does it have to be large to sync with the RubyOF window?
    
    
    @message_history.read do |message|
      parse_blender_data message
    end
    # ^ this method of merging history can't prevent spikes due to
    #   expensive operations like window sync that take more than 1 frame,
    #   but the old way couldn't deal with that either.
    
    
    
    # update_t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    # dt = update_t1 - update_t0
    # puts "TOTAL UPDATE TIME: #{dt}" if dt > 10
    
  end
  
  def send_to_blender(message)
    @blender_link.print message
  end
  
  def reset
    @blender_link.reset
  end
  
  
  
  
  
  private
  
  
  
  
  
  
  
  
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
    
    
    case message['type']
    when 'delete_lights'
      # delete any lights with names on this list
      puts "gc lights"
      @world.lights.gc message['list']
      
    when 'viewport_camera'
      # sent on viewport update, not every frame
      # puts "update viewport"
      
      @world.camera.tap do |camera|
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
        update_entity(message)
        
      when 'LIGHT'
        # load transform AND data for lights here as necessary
        # ('data' field has already been linked to necessary data)
        
        # puts "loading light: #{message['name']}"
        
        light =
          @world.lights.fetch(message['name']) do |name|
            # if light with this name does not exist, create it
            BlenderLight.new(name)
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
    
    when 'update_geometry_data'
      update_geometry_data(message)
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
      # blender has reset, so reset all RubyOF data
      
      puts "== reset"
      reset()
      @world.transport.reset(self)
      
      puts "====="
      
    when 'pause'
      puts "== pause"
      @world.transport.pause(self)
      
      puts "====="
      
      
    when 'play'
      puts "== play"
      @world.transport.play(self)
      
      puts "====="
      
    
    when 'seek'
      @world.transport.seek(self, message['time'])
      
    end
  end
  
  
  
  
  # 
  # handle update messages from BlenderSync
  # 
  
  
  # TODO: update this file and exporter.py to only use a small set of signals to reload textures
  
  def update_geometry_data(message)
    p message
    
    
    json_path = message['json_file_path']
    position_path = message['position_tex_path']
    normal_path = message['normal_tex_path']
    entity_path = message['entity_tex_path']
    
    
    base_dir = PROJECT_DIR/'bin'/'data'/'geom_textures'
    # prefix = "Tiles"
    # json_path    = base_dir/"#{prefix}.cache.json"
    # position_path = base_dir/"#{prefix}.position.exr"
    # normal_path   = base_dir/"#{prefix}.normal.exr"
    # entity_path   = base_dir/"#{prefix}.entity.exr"
    
    
    case message['comment']
    when 'moved entity'
      @world.on_entity_moved(self, base_dir, message['name'])
      
    when 'created new entity with new mesh'
      @world.on_entity_created_with_new_mesh(self, base_dir, message['name'])
      
    when 'created new entity with existing mesh'
      @world.on_entity_created(self, base_dir, message['name'])
      
    when 'edit active mesh'
      @world.on_mesh_edited(self, base_dir, message['name'])
      
    when 'edit material for all instances'
      @world.on_material_edited(self, base_dir, message['name'])
      
    when 'run garbage collection'
      # NOTE: this can be called when cache is cleared from Blender, which means that there might not actually be a file at the JSON path
      @world.on_gc(self, base_dir, message['name'])
    when 'export all textures'
      @world.on_full_export(self, base_dir, message['name'])
    end
    
    
    # # reload history, etc
    # # (code adapted from Core#on_reload)
    # @world.on_reload_data(self)
    
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
      delta = CP::Vec2.new(-2.000, -100.000)*-1
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
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  # Implement an interface similar to ruby's Ractor,
  # which is based on the actor pattern
  class ActorChannel
    def initialize
      @fifo_dir = PROJECT_DIR/'bin'/'run'
    end
    
    
    def start
      # 
      # Open FIFO in main thread then pass to Thread using function closure.
      # This prevents weird race conditions.
      # 
      # Consider this timing diagram:
      #   main thread         @incoming_thread
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
      #   but the ensure block of @incoming_thread will try close f_r.
      #   This results in an exception, 
      #   which prevents the FIFO from being properly deleted.
      #   This will then cause an error when the program is restarted / reloaded
      #   as a FIFO can not be created where one already exists.
      
      @f_r = File.open(make_fifo(@fifo_dir/'blender_comm'), "r+")
      
      # NOTE: @incoming_port and @outgoing_port always hold JSON-encoded strings, not other types of ruby objects.
      # (see #send and #take for details)
      
      @incoming_port = Queue.new
      
      @incoming_thread = Thread.new do
        begin
          puts "#{self.class}: incoming thread start"
          loop do
            data = @f_r.gets # blocking IO
            @incoming_port << data
          end
        ensure
          puts "#{self.class}: incoming thread stopped"
        end
      end
      
      
      
      
      @outgoing_port = Queue.new
      
      @outgoing_thread = Thread.new do
        puts "#{self.class}: outgoing thread start"
        
        @outgoing_fifo_path = make_fifo(@fifo_dir/'blender_comm_reverse')
        begin
          loop do
            # NOTE: FIFO must be re-opened right after pipe is broken, otherwise we can't detect when writers connect
            
            begin
              if @f_w.nil?
                puts "#{self.class}: opening outgoing pipe"
                
                # clear all messages put into the the buffer
                # while the port was closed
                # puts "clear @outgoing_port"
                # @outgoing_port.clear
                # ^ shouldn't near to clear again
                #   how would anything get into the queue?
                #   if the thread is down, then the system
                #   should not be updating game state, just trying
                #   to load new code / old history to get
                #   into a decent state again
                
                # blocks on open if no writers
                @f_w = File.open(@outgoing_fifo_path, "w")
                puts "pipe opened"
                
              end
              
              message = @outgoing_port.pop # will block thread when Queue empty
              p message
              @f_w.puts message              
              @f_w.flush
              
              # puts "queue size: #{@outgoing_port.size}"
            rescue Errno::EPIPE => e
              puts "#{self.class}: outgoing pipe broken" 
              
              # NOTE: incoming port's queue will be cleared on restart
              
              # can't close the file here - will get an execption
              # but must open the FIFO again before writing
              
              # signal that FIFO should be reopened at the top of the loop
              @f_w = nil
            end
            
          end
        ensure
          # This outer ensure block is only for when thread exits.
          
          puts "#{self.class}: outgoing thread stopped"
          
          p @f_w
          p @outgoing_fifo_path
          
          # can't close if file handle was never set
          @f_w&.close
          
          # FIFO is always made even if not opened,
          # so always need to remove from the filesystem.
          FileUtils.rm(@outgoing_fifo_path)
            # can't use @f_w.path, because if no readers ever connect,
            # then the FIFO never opens,
            # and then @f_w == nil
          
          
          # @outgoing_status = :closed # NOTE(1): status set to closed here...
          puts "clear @outgoing_port"
          @outgoing_port.clear
          
          @f_w = nil # NOTE(3): setting the file handle to nil fixes the problem for now
          
          puts "outgoing fifo closed"
        end
        
        # NOTE: can use unix `cat` to monitor the output of this named pipe
        
      end
    end
    
    # blender has connected
    # resume sending data via the output port
    def reset
      # @outgoing_port.clear
      
      # @outgoing_status = :open # NOTE(2): ...but set to open here. thus, once the FIFO is closed, @outgoing_status will be :open when the new thread starts up, and the thread will not attempt to open it again.
      # Need to fundamentally fix the problem with this signalling structure in order to fix the bug. think about how the file is used, but also how the Queue is used to communicate with the rest of the system in the main thread. Perhaps we're conflating two different signals? Need to look into this.
      # p "status: #{@outgoing_status}"
    end
    
    
    
    
    # 
    # close communication channels
    # 
    
    def stop
      @incoming_thread.kill.join
      @outgoing_thread.kill.join
      
      # Release resources here instead of in ensure block on thread because the ensure block will not be called if the program crashes on first #setup. Likely this is because the program is terminating before the Thread has time to start up.
      
      p @f_r
      p @f_r.path
      
      @f_r.close
      FileUtils.rm(@f_r.path)
      puts "incoming fifo closed"
      
      
      
    end
    
    # 
    # communication is stopped if FIFOs do not exist on filesystem
    # 
    def stopped?
      return !File.exists?(@f_r.path)
    end
    
    
    # 
    # communicate via json messages
    # 
    
    # Send a message from ruby to python
    # (supress message if port is closed)
    def print(message)
      # if the port is open, queue the message (should go out soon)
      # if the port is closed, supress the message (don't even queue it up)
      
      
      # NOTE: can't use thread aliveness to figure out whether or not to queue messages. is there some other signal I can use? Ideally want to not to write to some variable in worker thread and main thread (thinking about future GIL-free parallelism - but maybe that's too far in the future?)
      
      # NOTE: current implementation doesn't crash, but doesn't clip the timeline range like hitting the blender button does. also requires manually turning the blender toggle back on.
        # can't reset the timeline on reset, because I can't send a loopback message to Blender
        # could possibly send a message when I figure out how to auto reconnect?
      
      if @outgoing_port == nil || !@outgoing_port.alive?
        # NO-OP
      else
        @outgoing_port.push message.to_json
      end
      
    end
    
    # Take the latest message from python to ruby out of the queue
    # (return nil if there are no messages in the queue)
    def take
      if @incoming_port.empty?
        return nil
      else
        # Queue#pop blocks the current thread while empty
        message_string = @incoming_port.pop
        message = JSON.parse message_string
        return message
      end
    end
    
    
    
    private
    
    
    def make_fifo(fifo_path)
      if fifo_path.exist?
        raise "ERROR: fifo (named pipe) already exists @ #{fifo_path}. Likely was not properly deleted on shutdown. Please manually delete the fifo file and try again."
      else
        File.mkfifo(fifo_path)
      end
      puts "fifo created @ #{fifo_path}"
      
      return fifo_path
    end
    
  end
  
end

