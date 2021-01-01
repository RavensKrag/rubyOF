class DependencyGraph
  def initialize()
    
    @cameras = {
      'viewport_camera' => ViewportCamera.new,
    }
    
    
    @lights = Array.new
    @light_material = RubyOF::Material.new
    # ^ materials used to visualize lights a small spheres in space.
    # color of this material may change for every light
    # so every light is rendered as a separate batch,
    # even though they all use the same sphere mesh.
    # (would need something like Unity's MaterialPropertyBlock to avoid this)
    # (for now, seems like creating the material is the expensive part anyway)
    
    
    # ^ materials used to visualize lights a small spheres in space
    # (basically just shows the color and position of each light)
    # (very important for debugging synchronization between RubyOF and blender)
    
    @mesh_objects    = Hash.new # {name => mesh }
    @mesh_datablocks = Hash.new # {name => datablock }
    
    
    @mesh_materials  = Hash.new # {name => material }
    # ^ standard materials for individual meshes
    # 
    #   (materials are NOT entities, by which I mean
    #    it is possible for a material and an entity
    #    to have the same name. )
    #  
    
    
    # actually, mesh objects and mesh datablocks can have overlaps in names too
    # but no two mesh datablocks can have the same name
    # and no two mesh objects can have the same name
    # (and I think the name of a mesh object can't overlap with say, a light?)
    
    
    
    
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
  
  
  # def pack_entities
  #   @entities.to_a.collect{ |key, val|
  #     val.data_dump
  #   }
  # end
  
  
  private
  
  
  def setup_lights_and_camera
    # camera begin
    @cameras['viewport_camera'].begin
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
      
      @light_material.tap do |mat|
        mat.emissive_color = light_color
        
        
        mat.begin()
        ofPushMatrix()
          ofDrawSphere(light_pos.x, light_pos.y, light_pos.z, 0.1)
        ofPopMatrix()
        mat.end()
      end
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
    @cameras['viewport_camera'].end
  end
  
  
  public
  
  
  
  # 
  # public interface with blender sync
  # 
  
  def viewport_camera
    return @cameras['viewport_camera']
  end
  
  def list_entity_names
    return [
      @cameras.keys,
      @lights.collect{ |x| x.name },
      @mesh_objects.keys
    ].compact 
  end
  
  
  def gc(active: [])
    entities = self.list_entity_names - ['viewport_camera']
    
    (entities - active).each do |entity_name|
      delete entity_name # also removes empty batches
    end
  end
  
  
  
  def add(entity)
    # TODO: guard against adding the same entity twice
    
    # always add entity to entity collection
    @entities[entity.name] = entity
    
    # then perform additional processing based on type
    case entity
    when BlenderMesh
      # => adds datablock to collection (need to pull datablock by name)
      # => adds entity to collection (need to pull entity by name)
      
      
      # batch = find_batch(@batches, entity)
      # batch.add entity
      
      
      
      # # implement as a triple store
      # @batches = [
      #   [entity.mesh, entity.material,  RenderBatch.new]
      #   [entity.mesh, entity.material,  RenderBatch.new]
      #   [entity.mesh, entity.material,  RenderBatch.new]
      # ]
      
      
      
      batch, i = find_batch_with_index @batches
      
      batch.add entity
      
      
      
      
      
      
      
      
    when BlenderLight
      # => add to list of lights
      @lights << entity
    end
    
    return entity
  end
  
  def delete(entity_name)
    entity = @entities.delete entity_name
    
    case entity
    when BlenderMesh
      # batch = find_batch(@batches, entity)
      # batch.delete entity
      
      
      batch, i = find_batch_with_index @batches
      
      batch.delete(entity)
      
      if batch.state == 'empty'
        @batches.delete_at i
      end
      
      
      
      # TODO: remove material if unused
      # TODO: remove mesh if unused
    when BlenderLight
      @lights.delete_if{ |light|  light.equal? entity }
    end
    
    return entity
  end
  
  
  
    # TODO: change batch initalizer to take 0 argument
    # TODO: batch should initialize as empty
    
  
  # assuming batch is organized by trees
  # where only the leaves store data
  # problem: results in mulitple places where new batch must be created
  #          (super ugly code)
  private def find_batch(assoc_tree, entity)
  # which object (mat or mesh) is at which internal node level is arbitrary
    
      # # lisp style
      # @batches = [
      #   ['mat1', [ ['mesh1',[1,2,3,4,5]]
      #              ['mesh2',[6,7,8]] ] ],
      #   ['mat2', [ ['mesh1',[9]] ] ]
      # ]
      
      # # (don't try pattern matching with assoc - it just makes things hairy)
      
      
      
      # @batches.assoc('mat1')&.last
      #        &.assoc('mesh1')&.last
      
      
      # level1_node = @batches.assoc('mat1')&.last
      # level2_node = level1_node&.assoc('mesh1')&.last
      # # => [mesh, [list of entities] ]
      # # a list of entities is essentially a batch,
      # # and then I need a new type for Batch, aka a new class
      # # (I mean, I have an implementation already, I need to update that)
    
  
    
    material = entity.material
    mesh = entity.mesh
    
    
    # @batches.assoc(entity.material)&.last
    #        &.assoc(entity.mesh)&.last
    # .tap do |batch|
    #   batch.add entity
    # end
    
    # # ok, but what if some of the nodes in the tree do not exist yet?
    
    
    parent = @batches
    
    node = parent.assoc(entity.material) # <-- assoc 1
    if node.nil?
      new_batch = RenderBatch.new()
      
      parent << [entity.material, [ [entity.mesh, new_batch] ] ]
      return new_batch
    else
      parent = node.last
      
      node = parent.assoc(entity.mesh)   # <-- assoc 2
      
      if node.nil?
        new_batch = RenderBatch.new()
        
        parent << [entity.mesh, new_batch]
        return new_batch
      else
        
        return node.last # => RenderBatch
        
      end
    end
    
    
    
    
    
    
  end
  
  
  # assuming batches are stored as triples:
  private def find_batch_with_index(batches)
    # find batch and index
    i = 
      @batches.find_index{ |mesh, mat, batch| 
        entity.mesh.equal? mesh and entity.material.equal? mat
      }
    
    if i.nil?
      batch = RenderBatch.new
      @batches << [entity.mesh, entity.material, batch]
      
      i = @batches.size-1
    end
    
    batch = @batches[i].last
    
    return batch, i
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
  end
  
  
  
  def find_mesh_datablock(mesh_name)
    return @mesh_datablocks[mesh_name]
  end
  
  
  
  def add_material(material)
    @mesh_materials[material.name] = material
    
    return material
  end
  
  def delete_material(material_name)
    material = @mesh_materials.delete material_name
    
    # TODO: delete from other places too
    # (what happens if there is a mesh with no material? when do you sound the alarm? don't want to error too early - may attach a new mat later - but if you do it too late it may be hard to detect what went wrong)
  end
  
  def find_material_datablock(material_name)
    return @mesh_materials[material_name]
  end
  
  
  
  
  # 
  # YAML serialization interface
  # 
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    
    # @cameras = {
    #   'viewport_camera' => ViewportCamera.new,
    # }
    
    
    # @lights = Array.new
    # @light_material = RubyOF::Material.new
    
    # @mesh_objects    = Hash.new # {name => mesh }
    # @mesh_datablocks = Hash.new # {name => datablock }
    
    
    # @mesh_materials  = Hash.new # {name => material }
    
    
    
    # no need to store the batches: just regenerate them later
    # (NOTE: this may slow down reloading for scenes with many batches. need to check the performance on this later)
    
    data_hash = {
      'viewport_camera' => @cameras['viewport_camera'],
      
      'lights' => @lights,
      'light_material' => @light_material,
      
      'mesh_objects'    => @mesh_objects,
      'mesh_datablocks' => @mesh_datablocks,
      'mesh_materials'  => @mesh_materials
    }
    coder.represent_map to_yaml_type, data_hash
    
    
    # mesh objects are linked to mesh datablocks. need to resolve that linkage manually, because relying on YAML to do that for you is slow
    # (or at least I think that was the bottleneck before)
    # maybe I want to find a different way to make this faster?
    
    # how will I serialize the materials?
    # (ideally I just want to write code within each Material explaining how to turn it into YAML..)
  end
  
  def init_with(coder)
    # initialize()
      @light_material = RubyOF::Material.new
      
    
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
    # @meshes = @batches.values.collect{ |batch|  batch.mesh } 
    @lights = coder.map['lights']
  end
  
end

class BatchKey
  attr_reader :mesh, :mat
  
  def initialize(mesh, mat)
    @mesh = mesh
    @mat = mat
  end
  
  def hash
    [@mesh.__id__, @mat.__id__].hash
  end
  
  def ==(other)
    self.class == other.class and 
      @mesh == other.mesh and @mat == other.mat
  end
  
  alias :eql? :==
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
        # ^ actually, shaders are now loaded in this very file
        #   see: reload_instancing_shaders()
        
        
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
        # draw instanced (v4.2 - 4x4 full transform matrix in texture)
        
        
        # set uniforms
        @mat_instanced.setCustomUniformTexture(
          "transform_tex", @instance_data.texture, 1
        )
          # but how is the primary texture used to color the mesh in the fragment shader bound? there is some texture being set to 'tex0' but I'm unsure where in the code that is actually specified
        
        # @mat_instanced.setInstanceMagnitudeScale(
        #   InstancingBuffer::FLOAT_MAX
        # )
        
        # @mat_instanced.setInstanceTextureWidth(
        #   @instance_data.width
        # )
        
        
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
        
        # NOTE: the shader source strings *will* be effected by the shader preprocessing pipeline in ofShader.cpp
        
        
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
  
