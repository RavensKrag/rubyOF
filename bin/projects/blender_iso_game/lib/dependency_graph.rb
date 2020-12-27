class DependencyGraph
  def initialize()
    @entities = {
      'viewport_camera' => ViewportCamera.new,
    }
    
    @meshes = Hash.new
    @lights = Array.new
    
    
    # material for visualizing lights
    @mat2 = RubyOF::Material.new
    # ^ update color of this material every time the light color changes
    #   not just on the first frame
    #   (creating the material is the expensive part anyway)
    
    
    
    # 
    # batch objects (for GPU instancing)
    # 
    
    # batching = 
    #   @entities.values
    #   .select{|x| x.is_a? BlenderMesh }
    #   .group_by{|x| x.mesh }
    
    @batches   = Hash.new  # single entities and instanced copies go here
                           # grouped by the mesh they use
    
  end
  
  # 
  # interface with core
  # 
  
  include RubyOF::Graphics
  def draw
    # puts ">>>>> batches: #{@batches.keys.size}"
    
    # t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    @batches.each do |mesh, batch|
      # puts "batch id #{batch.__id__}"
      batch.update
    end
    
    # t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # dt = t1-t0
    # puts "time - batch update: #{dt.to_f / 1000} ms"
    
    
    # RubyOF::FloatColor.rgb([5, 1, 1]).tap do |c|
    #   print "color test => "
    #   puts c
    #   print "\n"
    # end
    
    
    
    # ========================
    # render begin
    # ------------------------
    begin
      setup_lights_and_camera()
      
      render_scene()
      
    
    # clean up lights and camera whether there is an exception or not
    # but if there's an exception, you need to re-raise it
    # (can't just use 'ensure' here)
    rescue Exception => e 
      finish_lights_and_camera()
      raise e
      
    else
      finish_lights_and_camera()
      
    end
    # ------------------------
    # render end
    # ========================
  end
  
  
  def pack_entities
    @entities.to_a.collect{ |key, val|
      val.data_dump
    }
  end
  
  
  private
  
  
  def setup_lights_and_camera
    # camera begin
    @entities['viewport_camera'].begin
    # 
    # setup GL state
    # 
    
    ofEnableDepthTest()
    ofEnableLighting() # // enable lighting //
    
    # 
    # enable lights
    # 
    
    # the position of the light must be updated every frame,
    # call enable() so that it can update itself
    @lights.each{ |light|  light.enable() }
  end
  
  def render_scene
    # 
    # render entities
    # 
    
    
    # render by batches
    # (RenderBatch automatically uses GPU instancing when necessary)
    @batches.each{|mesh, batch|  batch.draw }
    
    
    # 
    # render the sphere that represents the light
    # 
    
    @lights.each do |light|
      light_pos   = light.position
      light_color = light.diffuse_color
      
      @mat2.emissive_color = light_color
      
      
      @mat2.begin()
      ofPushMatrix()
        ofDrawSphere(light_pos.x, light_pos.y, light_pos.z, 0.1)
      ofPopMatrix()
      @mat2.end()
    end
  end
  
  def finish_lights_and_camera
    # 
    # disable lights
    # 
    
    # // turn off lighting //
    @lights.each{ |light|  light.disable() }
    
    
    # 
    # teardown GL state
    # 
    
    ofDisableLighting()
    ofDisableDepthTest()
    
    # camera end
    @entities['viewport_camera'].end
  end
  
  
  public
  
  
  
  # 
  # public interface with blender sync
  # 
  
  def viewport_camera
    return @entities['viewport_camera']
  end
  
  
  def gc(active: [])
    (@entities.keys - active - ['viewport_camera'])
    .each do |deleted_entity_name|
      self.delete deleted_entity_name
      
    end
    
    @batches.delete_if do |mesh, batch|
      batch.state == 'empty'
    end
  end
  
  
  
  def add(entity)
    case entity
    when BlenderMesh
      # => adds datablock to collection (need to pull datablock by name)
      # => adds entity to collection (need to pull entity by name)
      @entities[entity.name] = entity
      
      # => associates datablock and entity with proper batch
      # (key should be the name, not the mesh, so that keys are immutable)
      # (was using the entire mesh before, but mutable keys get spooky effects)
      mesh_name = entity.mesh.name
      if @batches.has_key? mesh_name
        @batches[mesh_name].add entity
      else
        @batches[mesh_name] = RenderBatch.new(entity)          
      end
      
    when BlenderLight
      # => add to list of lights
      @lights << entity
      # => add to entity collection (need to pull it by name later)
      @entities[entity.name] = entity
      
    end
  end
  
  def delete(entity_name)
    entity = @entities.delete entity_name
    
    case entity
    when BlenderMesh
      @batches[entity.mesh.name].delete entity
    when BlenderLight
      @lights.delete_if{ |light|  light.equal? entity }
    end
  end
  
  def find_entity(entity_name)
    return @entities[entity_name]
  end
  
  def find_datablock(datablock_name)
    # assumes all datablocks are mesh datablocks
    # (linked lighting data is not supported)
    # (other blender object types, such as camera, are not yet implemented)
    @batches.values
    .collect{ |batch| batch.mesh }
    .find{ |mesh_datablock| mesh_datablock.name == datablock_name }
    
    # TODO: when you delete some instances from the world, the position data gets messed up. it's easily fixed with an additional move, but maybe there's a more elegant way... basically, the code implictily assumes that the deleted meshes are the ones with indicies at the end of the list, but this is not necessarily the case. thus, if you don't update all positions on deletion, then the "wrong instances" appear to be deleted. This is not exactly the case, but it's a pretty weird graphical effect, regaurdless.
    
  end
  
  
  
  # 
  # YAML serialization interface
  # 
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    # @entities = {
    #   'viewport_camera' => ViewportCamera.new,
    # }
    #
    # @meshes = Hash.new
    #
    # @batches   = Hash.new  # single entities and instanced copies go here
    #                        # grouped by the mesh they use
    
    data_hash = {
      'entity_list' => @entities.values.select{|x| 
                            !x.is_a? BlenderMesh  },
      'batch_list'  => @batches.values,
      'lights'      => @lights,
    }
    coder.represent_map to_yaml_type, data_hash
  end
  
  def init_with(coder)
    # initialize()
      @mat2 = RubyOF::Material.new
      
    
    # all batches using GPU instancing are forced to refresh position on load
    @batches = Hash.new
      coder.map['batch_list'].each do |batch|
        @batches[batch.mesh.name] = batch
      end
    
    @entities = Hash.new
      coder.map['entity_list'].each do |entity|
        @entities[entity.name] = entity
      end
      @batches.each_value do |batch|
        batch.each do |entity|
          @entities[entity.name] = entity
        end
      end
    
    # Hash#values returns copy, not reference
    @meshes = @batches.values.collect{ |batch|  batch.mesh } 
    @lights = coder.map['lights']
  end
  
end

class RenderBatch
    # NOTE: can't use state machine because it requires super() in initialize
    # and I need to bypass initialize() when loading from YAML
    attr_reader :state # read only: state is always managed interally
    attr_reader :mesh  # read only: once you assign a mesh, it's done
    
    def initialize(mesh_obj)
      @mesh = mesh_obj.mesh
      @entity_list = [mesh_obj]
      
      @state = 'single' # ['single', 'instanced_set', 'empty']
      
      setup()
    end
    
    # setup is called by the YAML loader, and bypasses initialize
    def setup()
      @batch_dirty = false
      
      # @mat1 and @mat_instanced should have the same apperance
      
      color = RubyOF::FloatColor.rgb([1, 1, 1])
      shininess = 64
      
      @mat1 = RubyOF::Material.new
      @mat1.diffuse_color = color
      # // shininess is a value between 0 - 128, 128 being the most shiny //
      @mat1.shininess = shininess
      
      
      @mat_instanced = RubyOF::OFX::InstancingMaterial.new
      @mat_instanced.diffuse_color = color
      @mat_instanced.shininess = shininess
      
      # TODO: eventually want to unify the materials, so you can use the same material object for single objects and instanced draw, but this setup will work for the time being. (Not sure if it will collapse into a single shader, but at least can be one material)
      
      
      
      @shader_timestamp = nil
      
      shader_src_dir = PROJECT_DIR/"ext/c_extension/shaders"
      @vert_shader_path = shader_src_dir/"phong_instanced.vert"
      @frag_shader_path = shader_src_dir/"phong.frag"
      
      
      @instance_data = InstancingBuffer.new
    end
    
    def update
      if @state == 'instanced_set'
        reload_instancing_shaders()
        update_packed_entity_positions()
      end
    end
    
    def add(mesh_obj)
      # TODO: may want to double-check that the entity being added uses the mesh that is managed by this batch
      
      @entity_list << mesh_obj
      
      if @entity_list.size > 1
        @state = 'instanced_set'
      elsif @entity_list.size > @instance_data.max_instances
        # raise exception if current texture size is too small
        # to hold packed position information.
        
        # NOTE: can't currently set size dynamically, because shader must be compiled with correct dimensions. may want to update dynamic shader compilation pipeline in OFX::InstancingMaterial
        
        msg = [
          "ERROR: Too many instances to draw using one position texture. Need to implement spltting them into separate batches, or something like that.",
          "Current maximum: #{@instance_data.max_instances}",
          "Instances requested: #{@entity_list.size}"
        ]
        
        raise msg.join("\n")
      end
    end
    
    def delete(mesh_obj)
      @entity_list.delete_if{|x| x.equal? mesh_obj }
      
      if @entity_list.size == 1
        @state = 'single'
      elsif @entity_list.size == 0
        @state = 'empty'
      end
      
      @batch_dirty = true
    end
    
    def draw()
      case @state
      when 'empty'
        # no-op
      when 'single'
        mesh_obj = @entity_list.first
        
        @mat1.begin()
          mesh_obj.node.transformGL()
          @mesh.draw()
          mesh_obj.node.restoreTransformGL()
        @mat1.end()
      when 'instanced_set'
        # draw instanced (v4 - translation + z-rot, stored in texture)
        # NOTE: doesn't actually store z-rot right now, it's position only (normalized vector in RGB, with A channel for normalized magnitude)
        
        
        # set uniforms
        @mat_instanced.setCustomUniformTexture(
          "position_tex", @instance_data.texture, 1
        )
          # but how is the primary texture used to color the mesh in the fragment shader bound? there is some texture being set to 'tex0' but I'm unsure where in the code that is actually specified
        
        @mat_instanced.setInstanceMagnitudeScale(
          InstancingBuffer::FLOAT_MAX
        )
        
        @mat_instanced.setInstanceTextureWidth(
          @instance_data.width
        )
        
        
        # draw all the instances using one draw call
        @mat_instanced.begin()
          @mesh.draw_instanced(@entity_list.size)
        @mat_instanced.end()
        
      end
      # no-op
    end
    
    def to_s
      return "(#{@mesh.name} => [#{@entity_list.size} :: #{@entity_list.collect{|x| x.name }.join(',')}] )"
    end
    
    # define each instead of exposing @entity_list
    def each() # &block
      @entity_list.each do |entity|
        yield entity
      end
    end
    
    
    # 
    # YAML serialization interface
    # 
    def to_yaml_type
      "!ruby/object:#{self.class}"
    end
    
    def encode_with(coder)
      entity_data = 
        @entity_list.collect do |entity|
          [entity.name, entity.encode_transform_to_base64].join("\n")
          # (don't need entity.mesh.name, because we're inside of a batch, where @mesh points to the shared mesh)
        end
      
      data_hash = {
        'count'       => entity_data.size, # for human reading of YAML
        'state'       => @state,
        'mesh'        => @mesh,
        'entity_list' => entity_data
      }
      coder.represent_map to_yaml_type, data_hash
    end
    
    def init_with(coder)
      setup()
      
      @state       = coder.map['state']
      @mesh        = coder.map['mesh']
      
      @entity_list = 
        coder.map['entity_list']
        .collect{|data_string| data_string.split("\n") }
        .collect do |name, base64_transform|
          entity = BlenderMesh.new(name, @mesh)
          entity.load_transform_from_base64(base64_transform)
        end
      
      # force update on all batches using GPU instancing
      # otherwise InstancingBuffer will be messed up.
      # 
      # (can't do it from the outside - will need to force this from within BatchInstancing, otherwise we have to expose variables in the public interface, which is bad.)
      reload_instancing_shaders()
      
      # @entity_list.each{  |entity|  entity.dirty = true }
      # update_packed_entity_positions()
      
      nodes = @entity_list.collect{  |entity| entity.node}
      @instance_data.pack_all_transforms(nodes)
      
    end
    
    
    private
    
    def reload_instancing_shaders
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
    end
    
    # get all the nodes marked 'dirty' and update their positions in the instance data texture. only need to do this when @state == 'instanced_set'
    def update_packed_entity_positions
      # NOTE: If this is the style I eventually settle on, the dirty flag should ideally be moved to a single flag on the entire batch, rather than one flag on each entity.
      
      if @batch_dirty or @entity_list.any?{|entity| entity.dirty }
        t0 = RubyOF::Utils.ofGetElapsedTimeMicros
        nodes = @entity_list.collect{|entity| entity.node}
        
        t1 = RubyOF::Utils.ofGetElapsedTimeMicros
        dt = t1-t0
        puts "time - gather mesh entities: #{dt.to_f / 1000} ms"
        
        
        @instance_data.pack_all_transforms(nodes)
        
        @entity_list.each{|entity| entity.dirty = false }
        @batch_dirty = false
      end
      
    end
  end
  
