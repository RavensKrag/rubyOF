
class BlenderSync
  MAX_READS = 20
  
  def initialize(window, depsgraph)
    @window = window
    @depsgraph = depsgraph
    # @entities = entities
    # @meshes = meshes
    
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
      data = @msg_queue.pop
      
      t0 = RubyOF::Utils.ofGetElapsedTimeMicros
      list = JSON.parse(data)
      # p list
      t1 = RubyOF::Utils.ofGetElapsedTimeMicros
      
      dt = t1-t0;
      puts "time - parse json: #{dt}"
      
      timestamps = list.select{|x| x['type'] == 'timestamp'}
      unless timestamps.empty?
        time = timestamps.first['end_time']
        dt = Time.now.strftime('%s.%N').to_f - time
        puts "transmision time: #{dt*1000} ms"
      end
      
      
      # TODO: need to send over type info instead of just the object name, but this works for now
      parse_blender_data(list)
      
    end
    
    update_t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    dt = update_t1 - update_t0
    puts "TOTAL UPDATE TIME: #{dt}" if dt > 10
    
  end
  
  
  # TODO: somehow consolidate setting of dirty flag for all entity types
  def parse_blender_data(data_list)
    
    t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    data_list.each do |data|
      
      # viewport camera updates (not a camera object)
      
      # material updates
      
      
      # transform
      # mesh
      # light property updates
      # camera object updates? (not implemented in Python script yet)
      
      
      # first process types with no transform component
      case data['type']
      when 'viewport_region'
        # 
        # sync window size
        # 
        
        w = data['width']
        h = data['height']
        @window.set_window_shape(w,h)
        
        # @camera.aspectRatio = w.to_f/h.to_f
        
        
        # 
        # sync window position
        # (assuming running on Linux)
        # - trying to match pid_query with pid_hit
        # 
        
        sync_window_position(blender_pid: data['pid'])
      when 'viewport_camera'
        # puts "update viewport"
        
        @depsgraph.viewport_camera.tap do |camera|
          camera.dirty = true
          
          camera.load(data)
        end
      when 'MATERIAL'
        
      when 'entity_list'
        # The viewport camera is an object in RubyOF, but not in Blender
        # Need to remove it from the entity list or the camera
        # will be deleted.
        @depsgraph.gc(active: data['list'])
      when 'timestamp'
        # not properly a Blender object, but a type I created
        # to help coordinate between RubyOF and Blender
        
        # t0 = data['time']
        # t1 = Time.now.strftime('%s.%N').to_f
        dt = Time.now.strftime('%s.%N').to_f - data['start_time']
        puts "roundtrip time: #{dt*1000} ms"
        
      else # other types of objects with transforms
        # get the entity
        
        # p data if data['name'] == nil
        
        entity = @depsgraph.get_entity(data['type'], data['name'])
        
        unless entity.nil?
          # puts "entity class: #{entity.class}"
          
          # NOTE: some updates change only transform or only data
          
          # first, process transform here:
          data['transform']&.tap do |transform|
            # entity.load_transform(transform)
            @depsgraph.update_entity_transform(entity, transform)
          end
          
          # then process object-specific properties:
          data['data']&.tap do |obj_data|
            @depsgraph.update_entity_data(entity, data['type'], obj_data)
          end
        end
        
      end
    end
    
    t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    dt = t1-t0;
    puts "time - parse data: #{dt} us"
    
    
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


