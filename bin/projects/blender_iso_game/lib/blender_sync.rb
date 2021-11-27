
class BlenderSync
  MAX_READS = 20
  
  def initialize(window, depsgraph, history, core)
    @window = window
    @depsgraph = depsgraph
    @history = history
    
    @core = core
    
    # two-way communication between RubyOF (ruby) and Blender (python)
    # implemented using two named pipes
    @blender_link = ActorChannel.new
    
  end
  
  def stop
    @blender_link.stop
  end
  
  def update
    # update_t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    
    # @blender_link.send
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
      
      
      # send all of this data to history
      @history.write message
      
    end
    
    # TODO: reactivate / reimplement history so state is maintained when code reloads
    
    # TODO: merge messages in order to catch up if possible?
      # like, responding to linked window mode is slow, but if we can drop some of the older messages (they're superceeded by the newer messages anyway) then we can maybe stop the framerate from tanking.
    
    # TODO: why can't the viewport be made about 1/4 of my screen size? why does it have to be large to sync with the RubyOF window?
    
    
    @history.read do |message|
      parse_blender_data message
    end
    # ^ this method of merging history can't prevent spikes due to
    #   expensive operations like window sync that take more than 1 frame,
    #   but the old way couldn't deal with that either.
    
    
    
    # update_t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    # dt = update_t1 - update_t0
    # puts "TOTAL UPDATE TIME: #{dt}" if dt > 10
    
    
    # 
    # send messages to Blender (python)
    # 
    message = {
      'type' => 'final_frame',
      'value' => @core.frame_history.frame_index
    }
    
    @blender_link.send message
    
    
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
    
    
    # Temporary storage for Blender backend datablocks, like mesh data,
    # before they become attached to an entity.
    @new_datablocks ||= Hash.new
    
    # depsgraph only stores materials that are associated with a batch, so we need to temporarily store materials here as they are loaded
    @new_materials ||= Hash.new
    
    
    # NOTE: current implementation puts state in @new_datablocks and @new_materials that will be tricky on reload / rewind. need to better handle this state
    
    
    
    # p @depsgraph.instance_variable_get("@mesh_objects")
    # p @new_datablocks
    puts "--- #{message['type']} ---"
    # puts message['type'] === 'bpy.types.Mesh'
    
    
    case message['type']
    when 'interrupt'
      if message['value'] == 'RESET'
        # blender has reset, so reset all RubyOF data
        @depsgraph.clear
      end
      
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
        
        puts "loading light: #{message['name']}"
        
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
      
      case message['name']
      when 'pause'
        @core.frame_history.pause
        
      when 'play'
        @core.frame_history.play
      
      when 'seek'
        @core.frame_history.seek(message['time'])
        
      end
    
    when 'object_to_id_map'
      @core.update_entity_mapping(message)
    
    when 'meshID_to_meshName'
      @core.update_mesh_mapping(message)
    
    when 'anim_texture_update'
      # update all 3 textures
      @core.update_anim_textures(message)
    
    when 'geometry_update'
      # position and normal data for one mesh has been updated
      @core.update_geometry(message)
    
    when 'material_update'
      # position data in transform texture has been updated
      # may effect one object, or many
      @core.update_material(message)
    
    
    else
      
      
    end
    
    
    # # ASSUME: if an object's 'data' field is set, then the linkage to unedrlying data has changed. If the field is not set, then no change.
    
    
    # # t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # # dt = t1-t0;
    # # puts "time - parse data: #{dt} us"
    
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
      # puts "delta: #{delta}"
      
      # measurements of manually positioned windows:
      # dx = 0 to 3  (unsure of exact value)
      # dy = -101    (strange number, but there it is)
      
      
      # 
      # apply the delta
      # 
      
      # just need to apply inverse of the measured delta to RubyOF windows
      delta = CP::Vec2.new(0, -100)*-1
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
      
      @fifo_dir = PROJECT_DIR/'bin'/'run'
      
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
      
      
      
      
      @outgoing_open = false
      
      @outgoing_port = Queue.new
      
      @outgoing_thread = Thread.new do
        begin
          puts "#{self.class}: outgoing thread start"
          
          fifo_dir = make_fifo(@fifo_dir/'blender_comm_reverse')
          
          loop do
            if !@outgoing_open
              # if @f_w.nil? || @f_w.closed?
              if @f_w.nil?
                @f_w = File.open(fifo_dir, "w")
              end
              # end
              
              
              @outgoing_open = true
            end
            
            message = @outgoing_port.pop # will block thread when Queue empty
            @f_w.puts message
            @f_w.flush
            
            
            sleep(0.1)
          end
          
          # NOTE: can use unix `cat` to monitor the output of this named pipe
          
        rescue Errno::EPIPE => e
          puts "#{self.class}: outgoing pipe broken. stopping" 
          @outgoing_open = false # do not set @f_w to nil, because it stores the path to the FIFO in the filesystem
          
          
          # can't close the file here - will get an execption
          
          
          # must open the FIFO again before writing
          
          
        ensure
          puts "#{self.class}: outgoing thread stopped"
        end
      end
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
      
      
      
      if @outgoing_open
        p @f_w
        p @f_w.path
        
        @f_w.close
      end
      FileUtils.rm(@f_w.path)
      puts "outgoing fifo closed"
    end
    
    
    # 
    # communicate via json messages
    # 
    
    # Send a message from ruby to python
    # (supress message if port is closed)
    def send(message)
      if @outgoing_open
        @outgoing_port.push message.to_json
      else
        # NO-OP
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

