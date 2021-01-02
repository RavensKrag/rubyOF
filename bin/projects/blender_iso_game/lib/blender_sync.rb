
class BlenderSync
  MAX_READS = 20
  
  def initialize(window, depsgraph)
    @window = window
    @depsgraph = depsgraph
    
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
      
      if fifo_path.exist?
        raise "ERROR: fifo (named pipe) already exists @ #{fifo_path}. Likely was not properly deleted on shutdown. Please manually delete the fifo file and try again."
      else
        File.mkfifo(fifo_path)
      end
      
      puts "fifo created @ #{fifo_path}"
      
      @f_r = File.open(fifo_path, "r+")
    
    @msg_queue = Queue.new
    @msg_thread = Thread.new do
      begin
        puts "fifo message thread start"
        loop do
          data = @f_r.gets # blocking IO
          @msg_queue << data
        end
      ensure
        puts "fifo message thread stopped"
      end
    end
  end
  
  def stop
    @msg_thread.kill.join
    
    # Release resources here instead of in ensure block on thread because the ensure block will not be called if the program crashes on first #setup. Likely this is because the program is terminating before the Thread has time to start up. 
    fifo_path = @fifo_dir/@fifo_name
    
    p @f_r
    p fifo_path
    
    @f_r.close
    FileUtils.rm(fifo_path)
    puts "fifo closed"
  end
  
  def update    
    update_t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    [MAX_READS, @msg_queue.length].min.times do
      data_string = @msg_queue.pop
      
      t0 = RubyOF::Utils.ofGetElapsedTimeMicros
      blender_data = JSON.parse(data_string)
      
      # File.open(PROJECT_DIR/'bin'/'data'/'blender_data.json', 'a+') do |f|
      #   f.puts data_string
      # end
      
      # p list
      t1 = RubyOF::Utils.ofGetElapsedTimeMicros
      
      dt = t1-t0;
      puts "time - parse json: #{dt}"
      
      
      
      # TODO: need to send over type info instead of just the object name, but this works for now
      parse_blender_data(blender_data)
      
    end
    
    update_t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    dt = update_t1 - update_t0
    puts "TOTAL UPDATE TIME: #{dt}" if dt > 10
    
  end
  
  
  # TODO: somehow consolidate setting of dirty flag for all entity types
  def parse_blender_data(blender_data)
    
    t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # data = {
    #     'timestamps' : {
    #         'start_time': total_t0,
    #         'end_time':   total_t1
    #     },
        
    #     'all_entity_names' : object_list,
        
    #     'datablocks' : datablock_export,
    #     'objects' : obj_export
    # }
    
    
    if blender_data['interrupt'] == 'RESET '
      # blender has reset, so reset all RubyOF data
      @depsgraph.gc(active: [])
      
      return
    end
    
    
    
    # process timestamps twice:
    # + calculate transmission time at the start of this function
    # + calculate roundtrip time at the end of this function
    timestamps = blender_data['timestamps']
    unless timestamps.nil?
      time = timestamps['end_time']
      dt = Time.now.strftime('%s.%N').to_f - time
      puts "transmision time: #{dt*1000} ms"
    end
    
    
    
    
    # only sent on update, not on initial
    blender_data['all_entity_names']&.tap do |entity_names|
      # The viewport camera is an object in RubyOF, but not in Blender
      # Need to remove it from the entity list or the camera
      # will be deleted.
      @depsgraph.gc(active: entity_names)
    end
    
    
    # sent on viewport update, not every frame
    blender_data['viewport_camera']&.tap do |camera_data|
      # puts "update viewport"
      
      @depsgraph.viewport_camera.tap do |camera|
        camera.dirty = true
        
        camera.load(camera_data)
      end
    end
    
    # sent on some updates, when window link enabled
    blender_data['viewport_region']&.tap do |region_data|
      # 
      # sync window size
      # 
      
      w = region_data['width']
      h = region_data['height']
      @window.set_window_shape(w,h)
      
      # @camera.aspectRatio = w.to_f/h.to_f
      
      
      # 
      # sync window position
      # (assuming running on Linux)
      # - trying to match pid_query with pid_hit
      # 
      
      sync_window_position(blender_pid: region_data['pid'])
    end
    
    
    
    
    
    # ASSUME: if an object's 'data' field is set, then the linkage to unedrlying data has changed. If the field is not set, then no change.
    
    new_datablocks = Hash.new
    
    blender_data['datablocks']&.tap do |datablock_list|
      datablock_list.each do |data|
        case data['type']
        when 'bpy.types.Mesh'
          # create underlying mesh data (verts)
          # to later associate with mesh objects (transform)
          # which sets the foundation for instanced geometry
          
          name = data['mesh_name']
          
          mesh_datablock = @depsgraph.find_mesh_datablock(name)
          if mesh_datablock.nil?
            mesh_datablock = BlenderMeshData.new(name)
            new_datablocks[name] = mesh_datablock
          end
          
          puts "load: #{data.inspect}"
          mesh_datablock.load_data(data)
          
          
        when 'bpy.types.Light'
          # associate light data with light objects
          # because I don't want to have linked lights in RubyOF
          blender_data['objects']&.tap do |object_list|
            object_list
            .select{|obj_data|  obj_data['type'] == 'LIGHT' }
            .each do |light_data|
              if light_data['data'] == data['light_name']
                light_data['data'] = data
              end
            end
          end
        when 'bpy.types.Material'
          puts "material recieved"
        end
      end
    end
    
    # p @depsgraph.instance_variable_get("@batches").values.collect{|x| x.to_s }
    
    
    
    
    if @test_material.nil?
      @test_material = BlenderMaterial.new('default')
      
      @test_material.diffuse_color = RubyOF::FloatColor.rgb([1, 1, 1])
      @test_material.shininess = 64
    end
    
    blender_data['materials']&.tap do |material_list|
      material_list.each do |data|
        # p data['color'][1..3] # => data is already an array of floats
        color = RubyOF::FloatColor.rgb(data['color'][1..3])
        puts color
        
        @test_material.diffuse_color = color
      end
    end
    
    
    
    blender_data['objects']&.tap do |object_list|
      object_list.each do |data|
        # set type-specific properties
        case data['type']
        when 'MESH'
          # associate mesh object (transform) with underlying mesh data (verts)
          
          # TODO: how do you handle an existing object being linked to a different mesh?
          
          
          # if 'data' field is set, assume that linkage must be updated
          name = data['name']
          
          mesh_entity = @depsgraph.find_mesh_object(name)
          if mesh_entity.nil?
            datablock_name = data['data']
            
            
            # 
            # find associated underlying mesh datablock
            # 
            
            # look for datablock in depsgraph
            mesh_datablock = @depsgraph.find_mesh_datablock(datablock_name)
            
            # if it's not in the depsgraph yet, it must be something that needs to be added on this frame, so it should be in new_datablocks
            if mesh_datablock.nil?
              mesh_datablock = new_datablocks[datablock_name]
            end
            
            raise "ERROR: mesh datablock '#{datablock_name}' requested but not declared." if mesh_datablock.nil?
            
            
            # 
            # create new mesh object
            # 
            
            mesh_entity = BlenderMesh.new(name, mesh_datablock)
            
            
            # 
            # associate with material
            # 
            
            # mat = @depsgraph.find_material_datablock("__default__")
            # mesh_entity.material = mat
            mesh_entity.material = @test_material
            
            
            # 
            # add mesh object to dependency graph
            # 
            
            @depsgraph.add mesh_entity
          end
          
          data['transform']&.tap do |transform_data|
            mesh_entity.load_transform(transform_data)
          end
        
        when 'LIGHT'
          # load transform AND data for lights here as necessary
          # ('data' field has already been linked to necessary data)
          name = data['name']
          
          light = @depsgraph.find_light(name)
          if light.nil?
            light = BlenderLight.new(name)
            
            @depsgraph.add light
          end
          
          light.disable()
          
          data['transform']&.tap do |transform_data|
            light.load_transform(transform_data)
          end
          
          data['data']&.tap do |core_data|
            light.load_data(core_data)
          end
        end
        
      end
      
    end
    
    
    
    t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    dt = t1-t0;
    puts "time - parse data: #{dt} us"
    
    
    # process this last for proper timing
    unless timestamps.nil?
      # t0 = data['time']
      # t1 = Time.now.strftime('%s.%N').to_f
      dt = Time.now.strftime('%s.%N').to_f - timestamps['start_time']
      puts "roundtrip time: #{dt*1000} ms"
    end
    
    
    
    
    
    
    
  end
  
  
  private
  
  
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
      puts "delta: #{delta}"
      
      # measurements of manually positioned windows:
      # dx = 0 to 3  (unsure of exact value)
      # dy = -101    (strange number, but there it is)
      
      
      # 
      # apply the delta
      # 
      
      # just need to apply inverse of the measured delta to RubyOF windows
      delta = CP::Vec2.new(0, -101)*-1
      @window.position = (blender_pos + delta).to_glm
      
      # NOTE: system can't apply the correct delta if Blender is flush to the left side of the screen. In that case, dx = -8 rather than 0 or 3. Otherwise, this works fine.
      
      
      
      
      # puts "my pid: #{Process.pid}"
    # end
  end
  
  def find_window_position(query_title_string, query_pid)
    puts "trying to sync window position ---"
    
    
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
    puts "wm_id: #{hit_wm_id}"
    
    
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
    
    
    puts "-------"
    
    return CP::Vec2.new(hit_px, hit_py)
  end
  
end


