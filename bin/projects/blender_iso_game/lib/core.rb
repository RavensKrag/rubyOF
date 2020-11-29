
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


class BlenderObject
  attr_accessor :name
  attr_accessor :dirty
  
  def initialize
    @dirty = false
      # if true, tells system that this datablock has been updated
      # and thus needs to be saved to disk
  end
end

class BlenderMeshData
  extend Forwardable
  
  attr_accessor :verts, :normals, :tris
  def_delegators :@mesh, :draw, :draw_instanced
  
  def initialize
    @mesh = RubyOF::VboMesh.new
  end
  
  def generate_mesh
    return unless !@verts.nil? and !@normals.nil? and !@tris.nil?
    
    
    # p mesh.methods
    @mesh.setMode(:triangles)
    
    
    t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # @normals.each_cons(3) do |vert|
    #   @mesh.addNormal(GLM::Vec3.new(*vert))
    # end
    
    # @tris.each do |vert_idxs|
    #   vert_coords = vert_idxs.map{|i|  @verts[i]  }
      
    #   vert_coords.each do |x,y,z|
    #     @mesh.addVertex(GLM::Vec3.new(x,y,z))
    #   end
    # end
    
    # p @mesh
    # p @normals
    RubyOF::CPP_Callbacks.generate_mesh(@mesh, @normals,
                                               @verts,
                                               @tris.flatten)
    
    t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    dt = t1-t0;
    puts "time - mesh generation: #{dt}"
    
  end
end

class BlenderMesh < BlenderObject
  extend Forwardable
  
  attr_reader :node
  attr_accessor :mesh
  attr_accessor :color
  
  def initialize
    @mesh = BlenderMeshData.new
    @node = RubyOF::Node.new
  end
  
  def_delegators :@node, :position, :position=,
                         :orientation, :orientation=,
                         :scale, :scale=
  
  
  # convert to a hash such that it can be serialized with yaml, json, etc
  def data_dump
    orientation = self.orientation
    position = self.position
    scale = self.scale
    
    {
        'type' => 'MESH',
        'name' =>  @name,
        
        'transform' => {
          'rotation' => [
            'Quat',
            orientation.w, orientation.x, orientation.y, orientation.z
          ],
          'position' => [
            'Vec3',
            position.x, position.y, position.z
          ],
          'scale' => [
            'Vec3',
            scale.x, scale.y, scale.z
          ]
        },
        
        # 'data' => {
        #   'verts': [
        #     'double', num_verts, tmp_vert_file_path
        #   ],
        #   'normals': [
        #     'double', num_normals, tmp_normal_file_path
        #   ],
        #   'tris' : index_buffer
        # }
    }
  end
end

class CustomCamera< BlenderObject
  extend Forwardable
  include RubyOF::Graphics
  
  def initialize
    super()
    
    
    @of_cam = RubyOF::Camera.new
    @scale = 1
  end
  
  def position=(x)
    @of_cam.position = x
    @position = x
  end
  
  def orientation=(x)
    @of_cam.orientation = x
    @orientation = x
  end
  
  def fov=(x)
    @of_cam.fov = x
    @fov = x
  end
  
  def_delegators :@of_cam, :position, :orientation, :fov
  
  # (defaults to viewport size and that works for me)
  
  # def aspect_ratio=(x)
  #   @of_cam.aspect_ratio = x
  # end
  
  def near_clip=(x)
    @of_cam.near_clip = x
    @near_clip = x
  end
  
  def far_clip=(x)
    @of_cam.far_clip = x
    @far_clip = x
  end
  
  def_delegators :@of_cam, :near_clip, 
                           :far_clip
  
  
  attr_accessor :scale # used for orthographic view only
  
  def ortho?
    return self.state?('ORTHO')
  end
  
  
  # 
  # general strategy 
  # 
  
  # in perspective mode use ofCamera,
  # but in othographic mode manually apply transforms
  # (this is a strategy utilized by ofxInfiniteCanvas)
  
  
  
  # 
  # parameters
  # 
  
  # position
  # rotation
  # fov
  # aspect ratio
  # near clip
  # far clip
  
  # ortho scale
  # ortho?
  
  
  
  # exact behavior of #begin and #end depends on the state of the camera
  # NOTE: may want to use a state machine here
  
  
  state_machine :state, :initial => 'PERSP' do
    state 'PERSP' do
      def begin(viewport = ofGetCurrentViewport())
        # puts "persp cam"
        @of_cam.begin
      end
      
      
      def end
        @of_cam.end
      end
    end
    
    state 'ORTHO' do
      def begin
        invertY = false;
        
        # puts "ortho cam"
        # puts @scale
        
        # NOTE: @orientation is a quat, @position is a vec3
        
        vp = ofGetCurrentViewport();
        
        ofPushView();
        ofViewport(vp.x, vp.y, vp.width, vp.height, invertY);
        # setOrientation(matrixStack.getOrientation(),camera.isVFlipped());
        lensOffset = GLM::Vec2.new(0,0)
        ofSetMatrixMode(:projection);
        # projectionMat = 
        #   GLM.translate(GLM::Mat4.new(1.0),
        #                 GLM::Vec3.new(-lensOffset.x, -lensOffset.y, 0.0)
        #   ) * GLM.ortho(
        #     - vp.width/2,
        #     + vp.width/2,
        #     - vp.height/2,
        #     + vp.height/2,
        #     @near_clip,
        #     @far_clip
        #   );
        
        
        # use negative scaling to flip Blender's z axis
        # (not sure why it ends up being the second component, but w/e)
        m5 = GLM.scale(GLM::Mat4.new(1.0),
                       GLM::Vec3.new(1, -1, 1))
        
        projectionMat = 
          GLM.ortho(
            - vp.width/2,
            + vp.width/2,
            - vp.height/2,
            + vp.height/2,
            @near_clip,
            @far_clip*@scale
          );
        ofLoadMatrix(projectionMat * m5);
        
        
        
        ofSetMatrixMode(:modelview);
        
        m0 = GLM.scale(GLM::Mat4.new(1.0),
                       GLM::Vec3.new(@scale, @scale, @scale))
        
        m1 = GLM.translate(GLM::Mat4.new(1.0),
                                @position)
        
        m2 = GLM.toMat4(@orientation)
        
        cameraTransform = m1 * m2
        
        modelViewMat = m0 * GLM.inverse(cameraTransform)
        # ^ maybe apply scale here?
        ofLoadViewMatrix(modelViewMat);
        
        
        
        # @scale of about 25 works great for testing purposes with no translation
        
      end
      
      
      def end
        ofPopView();
      end
    end
    
    
    event :use_orthographic_mode do
      transition any => 'ORTHO'
    end
    
    event :use_perspective_mode do
      transition any => 'PERSP'
    end
  end
  
  
  # convert to a hash such that it can be serialized with yaml, json, etc
  def data_dump
    {
        'type' => 'viewport_camera',
        'view_perspective' => self.state,
        'rotation' => [
          'Quat',
          @orientation.w, @orientation.x, @orientation.y, @orientation.z
        ],
        'position' => [
          'Vec3',
          @position.x, @position.y, @position.z
        ],
        'fov' => [
          'deg',
          @fov
        ],
        'ortho_scale' => [
          'factor',
          @scale
        ],
        'near_clip' => [
          'm',
          @near_clip
        ],
        'far_clip' => [
          'm',
          @far_clip
        ]
    }
  end
  
end

class BlenderLight < BlenderObject
  extend Forwardable
  
  def initialize
    @light = RubyOF::Light.new
    
    setPointLight()
    
    @size = nil
    @size_x = nil
    @size_y = nil
  end
  
  
  def setPointLight()
    @type = 'POINT'
    
    @light.setPointLight()
  end
  
  def setDirectional()
    @type = 'SUN'
    
    @light.setDirectional()
  end
  
  def setSpotlight(cutoff_radians, exponent)
    @type = 'SPOT'
    
    @size = cutoff_radians
    
    size_deg = cutoff_radians / (2*Math::PI) * 360
    @light.setSpotlight(size_deg, 0) # requires 2 args
    # float spotCutOff=45.f, float exponent=0.f
  end
  
  def setAreaLight(width, height)
    @type = 'AREA'
    
    @size_x = width
    @size_y = height
    
    @light.setAreaLight(@size_x, @size_y)
  end
  
  
  def_delegators :@light, :position, :orientation, :scale,
                          :position=, :orientation=, :scale=,
                          :enable, :disable, :enabled?,
                          :diffuse_color=, :specular_color=, :ambient_color=,
                          :diffuse_color
  
  
  def data_dump
    orientation = self.orientation
    position = self.position
    scale = self.scale
    
    color = self.diffuse_color.to_a
            .first(3) # discard alpha component
            .map{|x| x / 255.0 } # convert to float from 0..1
    
    {
        'type' => 'LIGHT',
        'name' =>  @name,
        'light_type' => @type,
        'rotation' => [
          'Quat',
          orientation.w, orientation.x, orientation.y, orientation.z
        ],
        'position' => [
          'Vec3',
          position.x, position.y, position.z
        ],
        'scale' => [
          'Vec3',
          scale.x, scale.y, scale.z
        ],
        'color' => ['rgb'] + color,
        'size' => [
          'radians', @size
        ],
        'size_x' => [
          'float', @size_x
        ],
        'size_y' => [
          'float', @size_y
        ]
    }
  end
end


class InstancingBuffer
  attr_reader :pixels, :texture
  
  def initialize
    @pixels = RubyOF::Pixels.new
    @texture = RubyOF::Texture.new
    
    @width = 256
    @height = 256
    @pixels.allocate(@width, @height)
    
    @texture.wrap_mode(:vertical => :clamp_to_edge,
                :horizontal => :clamp_to_edge)
      
    @texture.filter_mode(:min => :nearest, :mag => :nearest) 
  end
  
  def pack_positions(positions)
    # positions.each_with_index do |pos, i|
    #   x = i / @width
    #   y = i % @width
      
    #   color = RubyOF::Color.rgba([*pos, 0])
    #   @pixels.setColor(x,y, color)
    # end
    
    # same logic as above, but need to make sure ofColorFloat
    RubyOF::CPP_Callbacks.pack_positions(@pixels, @width, @height)
    # TODO: wrap ofColor_<float> because lighting needs that too
      # (well, presumably everything that touches OpenGL ultimately needs floatig point color)
    
    
    
    # _pixels->getColor(x,y);
    # _tex.loadData(_pixels, GL_RGBA);
    @texture.loadData(@pixels)
    
  end
  
  def max_instances
    return @width*@height
  end
end



class BlenderSync
  MAX_READS = 20
  
  def initialize(window, entities, meshes)
    @window = window
    @entities = entities
    @meshes = meshes
    
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
    
    # p @entities.keys
    # p @entities.values.select{|x| x.is_a? BlenderMesh }.map{|x| x.name }
    
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
        
        @entities['viewport_camera'].tap do |camera|
          camera.dirty = true
          
          camera.position    = GLM::Vec3.new(*(data['position'][1..3]))
          camera.orientation = GLM::Quat.new(*(data['rotation'][1..4]))
          camera.near_clip   = data['near_clip'][1]
          camera.far_clip    = data['far_clip'][1]
          
          # p data['aspect_ratio'][1]
          # @camera.setAspectRatio(data['aspect_ratio'][1])
          # puts "force aspect ratio flag: #{@camera.forceAspectRatio?}"
          
          # NOTE: Aspect ratio appears to do nothing, which is bizzare
          
          
          # p data['view_perspective']
          case data['view_perspective']
          when 'PERSP'
            # puts "perspective cam ON"
            camera.use_perspective_mode
            
            camera.fov = data['fov'][1]
            
          when 'ORTHO'
            camera.use_orthographic_mode
            camera.scale = data['ortho_scale'][1]
            # TODO: scale needs to change as camera is updated
            # TODO: scale zooms as expected, but also effects pan rate (bad)
            
            
          when 'CAMERA'
            
            
          end
        end
      when 'MATERIAL'
        
      when 'entity_list'
        # The viewport camera is an object in RubyOF, but not in Blender
        # Need to remove it from the putative list such or the camera
        # will be deleted.
        (@entities.keys - data['list'] - ['viewport_camera'])
        .each do |deleted_entity_name|
          @entities.delete deleted_entity_name
        end
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
        
        entity = @entities[data['name']]
          # NOTE: names in blender are unique 
          # TODO: what happens when an object is renamed?
          # TODO: what happens when an object is deleted?
        
        
        # create entity if one with that name does not already exist
        if entity.nil?
          entity = 
            case data['type']
            when 'MESH'
              BlenderMesh.new
            when 'LIGHT'
              next
            when 'CAMERA'
              # not yet implemented
              # (skip the whole loop, because we can't process this right now)
              next 
            end
          
          
          entity.name = data['name']
          
          @entities[data['name']] = entity
        end
        
        
        # NOTE: possible for some updates to change only transform or only data
        
        # first, process transform here:
        data['transform']&.tap do |transform|
          pos   = GLM::Vec3.new(*(transform['position'][1..3]))
          quat  = GLM::Quat.new(*(transform['rotation'][1..4]))
          scale = GLM::Vec3.new(*(transform['scale'][1..3]))
          
          entity.position = pos
          entity.orientation = quat
          entity.scale = scale
        end
        
        # then process object-specific properties:
        data['data']&.tap do |obj_data|
          case data['type']
          when 'MESH'
            puts "mesh data"
            # p data
            
            mesh = @meshes[obj_data['mesh_name']]
            
            if mesh.nil?
              mesh = entity.mesh
              
              mesh.tris = obj_data['tris']
              
              obj_data['normals'].tap do |type, count, path|
                lines = File.readlines(path)
                
                # p lines
                # b64 -> binary -> array
                puts lines.size
                # if @last_mesh_file_n != path
                  # FileUtils.rm @last_mesh_file_n unless @last_mesh_file_n.nil?
                  
                  # @last_mesh_file_n = path
                  data = lines.last # should only be one line in this file
                  mesh.normals = Base64.decode64(data).unpack("d#{count}")
                  
                  # # assuming type == double for now, but may want to support other types too
                # end
                
                entity.dirty = true
              end
              
              obj_data['verts'].tap do |type, count, path|
                # p [type, count, path]
                
                lines = File.readlines(path)
                
                # p lines
                # b64 -> binary -> array
                puts lines.size
                # if @last_mesh_file_v != path
                  # FileUtils.rm @last_mesh_file_v unless @last_mesh_file_v.nil?
                  
                  # @last_mesh_file_v = path
                  data = lines.last # should only be one line in this file
                  # puts "data =>"
                  # p data
                  mesh.verts = Base64.decode64(data).unpack("d#{count}")
                  
                  # # assuming type == double for now, but may want to support other types too
                # end
                
                entity.dirty = true
              end
              
              
              if entity.dirty
                puts "generate mesh"
                mesh.generate_mesh()
              end
              
              @meshes[obj_data['mesh_name']] = entity.mesh
            else
              entity.mesh = mesh
            end
            
            
          
          when 'LIGHT'
            light = entity
            
            
            light.disable()
            
            
            
            case obj_data['light_type']
            when 'POINT'
              # point light
              light.setPointLight()
            when 'SUN'
              # directional light
              light.setDirectional()
              
              # (orientation is on the opposite side of the sphere, relative to what blender expects)
              
            when 'SPOT'
              # spotlight
              size_rad = obj_data['size'][1]
              size_deg = size_rad / (2*Math::PI) * 360
              light.setSpotlight(size_deg, 0) # requires 2 args
              # float spotCutOff=45.f, float exponent=0.f
            when 'AREA'
              width  = obj_data['size_x'][1]
              height = obj_data['size_y'][1]
              light.setAreaLight(width, height)
            end
            
            # # color in blender as float, currently binding all colors as unsigned char in Ruby (255 values per channel)
            color_ary = obj_data['color'][1..3].map{|x| (x*0xff).round }
            color = RubyOF::Color.rgba(color_ary + [255])
            # light.diffuse_color  = color
            # # light.diffuse_color  = RubyOF::Color.hex_alpha(0xffffff, 0xff)
            # light.specular_color = RubyOF::Color.hex_alpha(0xff0000, 0xff)
            
            
            white = RubyOF::Color.rgb([255, 255, 255])
            
            # // Point lights emit light in all directions //
            # // set the diffuse color, color reflected from the light source //
            light.diffuse_color = color
            
            # // specular color, the highlight/shininess color //
            light.specular_color = white
            
            
            
            
            
          end
        end
        
        
      end
    end
      
      # TODO: need to update python code to match new data format
      
    
    
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
      'viewport_camera' => CustomCamera.new,
      
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
    # puts "draw cube"
    # File.open(@fifo_dir/@fifo_name, "r") do
      
    # end
    
    
    # (may need to open the fifo and write something to it, so we get an EOF descriptor that will be useful for implementing non-blocking IO)
    
    # puts "<---"
    
    
    
    
    
    c = RubyOF::Color.hex_alpha( 0xf6bfff, 0xff )
    
    
    
    
    
    
    light_pos = @entities['Light'].position
    
    
    @entities['viewport_camera'].begin
    
      
      # // 
      # // my custom code
      # // 
      
      
      # // lets make a sphere with more resolution than the default //
      # // default is 20 //
      
      if @first_draw
        # ofBackground(10, 10, 10, 255);
        # // turn on smooth lighting //
        ofSetSmoothLighting(true)
        
        ofSetSphereResolution(32)
        
        
        
        @mat1 ||= RubyOF::Material.new
        # @mat1.diffuse_color = RubyOF::Color.rgb([0, 255, 0])
        @mat1.diffuse_color = RubyOF::Color.rgb([255, 255, 255])
        # // shininess is a value between 0 - 128, 128 being the most shiny //
        @mat1.shininess = 64
        
        
        
        @mat2 ||= RubyOF::Material.new
        # ^ update color of this material every time the light color changes
        #   not just on the first frame
        #   (creating the material is the expensive part anyway)
        
        
        
        @mat_instanced ||= RubyOF::OFX::InstancingMaterial.new
        @mat_instanced.diffuse_color = RubyOF::Color.rgb([255, 255, 255])
        @mat_instanced.shininess = 64
        
        
        @first_draw = false
        
      end
      
      light_color = @entities['Light'].diffuse_color
      @mat2.emissive_color = light_color
      
      
      # light_pos = GLM::Vec3.new(4,-5,3);
      # cube_pos = GLM::Vec3.new(0,0,0);
      
      
      ofEnableDepthTest()
        @entities['Light'].position = light_pos
        
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
              
              # ext/openFrameworks/examples/gl/vboMeshDrawInstancedExample/src/ofApp.cpp
              # ext/openFrameworks/libs/openFrameworks/gl/ofMaterial.cpp
              # bin/projects/blender_iso_game/ext/c_extension/ofxInstancingMaterial.cpp
              
                
                
              # # PROTOTYPE - draw all elements in separate draw calls, no GPU instancing (just testing the basic material functionality)
              
              # @mat_instanced.begin()
              #   mesh_objs.each do |mesh_obj|
              #     mesh_obj.node.transformGL()
              #     mesh_data.draw()
              #     mesh_obj.node.restoreTransformGL()
              #   end
              # @mat_instanced.end()
              
              
              # # TODO: bind Vbo#setAttributeData()
              # # TODO: bind Node#getLocalTransforMatrix
              # # TODO: bind Node#getGlobalTransformMatrix
              #     obj.node.position
              
              
                
              #   # https://forum.openframeworks.cc/t/how-to-set-custom-data-to-ofvbo/18296
              #   # 
              #   # ^ great explanation here of how to get the data into the shader. but I still need to figure out how to make this work with materials.

              # https://forum.openframeworks.cc/t/opengl-wrapper-vbo-and-shader-location/24760
              
              
              
              
              # 
              # v4 - translation + z-rot, stored in texture
              # 
              
              @instance_data ||= InstancingBuffer.new
              
              
              # collect up all the transforms
              positions = 
                mesh_objs.collect do |mesh_obj|
                  mesh_obj.node.position.to_a
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
              
              # # 
              # # Option 1
              # # more manual
              # # 
              
              # shader.setUniformTexture("position_tex", tex, 1)
              #   # TODO: bind this fx (polymorphic)
              #   # void ofShader::setUniformTexture(const string & name, const ofTexture& tex, int textureLocation)
              # tex.bind(1) # not the default slot
              
              # tex.unbind(1)
              
              
              
              # 
              # Option 2
              # associate texture with material
              # using stuff already declared by material
              # 
              @mat_instanced.setCustomUniformTexture(
                "position_tex", @instance_data.texture, 1
              )
              
              
              # but how is the primary texture used to color the mesh in the fragment shader bound? there is some texture being set to 'tex0' but I'm unsure where in the code that is actually specified
              
              
              @mat_instanced.begin()
              
              # draw all the instances using one draw call
              mesh_data.draw_instanced(mesh_objs.size)
              
              @mat_instanced.end()
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
            
            
            
            
            
            
            
            
            # NOTE: not currently getting any speedup by rendering this way... may need to use ofVboMesh class to get benefits of instancing. Not sure if there's a downside to just using this all the time???
            
            
            # cube_pos = mesh_obj.node.position
            # ofPushMatrix()
            #   mesh_obj.node.transformGL()
            #   ofDrawBox(0,0,0, 2)
            #   mesh_obj.node.restoreTransformGL()
            #   # ofDrawBox(cube_pos.x, cube_pos.y, cube_pos.z, 2)
            # ofPopMatrix()
          end
            
          
          
          # // render the sphere that represents the light
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
    
    
    
    
    
    
    
    
    
    # @entities['Cube'].generate_mesh
    
    # # raise "test error"
    
    
    
    # # NOTE: ofMesh is not a subclass of ofNode, but ofLight and ofCamera ARE
    # # (thus, you don't need a separate node to track the position of ofLight)
    
    # if @first_update
    #   # ofEnableDepthTest()
    #   # @entities['Light'].setup
      
      
    #   # @first_update = false
    # end
    
    # ofEnableDepthTest()
    # # ofEnableLighting()
    # @entities['Light'].enable
    # @entities['viewport_camera'].begin
    #   # puts @entities['viewport_camera'].getProjectionMatrix
      
    #   # @entities['Light'].setDirectional()
    #   # @entities['Light'].lookAt(@entities['Cube'].node.position)
        
    #     # material = RubyOF::Material.new
    #     # # material.ambient_color  = RubyOF::Color.hex_alpha(0xff0000, 0xff)
    #     # # material.diffuse_color  = RubyOF::Color.hex_alpha(0xff0000, 0xff)
    #     # @entities['Cube'].color.tap do |c| 
    #     #   unless c.nil?
    #     #     puts c
    #     #     # material.ambient_color = c
    #     #     material.diffuse_color = c
    #     #   end
    #     # end
    #     # material.specular_color = RubyOF::Color.hex_alpha(0xffffff, 0xff)
        
    #     # # material.begin
        
          # @entities['Cube'].node.transformGL()
          # @entities['Cube'].mesh.draw()
          # @entities['Cube'].node.restoreTransformGL()
        
    #     # material.end
        
    #     cube_pos = @entities['Cube'].node.position
    #     ofDrawBox(cube_pos.x, cube_pos.y, cube_pos.z, 2)
        
        
    #     light_pos = @entities['Light'].position
    #     ofDrawSphere(light_pos.x, light_pos.y, light_pos.z, 0.1)
      
    
    # @entities['viewport_camera'].end
    # @entities['Light'].disable
    # # ofDisableLighting()
    # ofDisableDepthTest()
    
    
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


  
  
