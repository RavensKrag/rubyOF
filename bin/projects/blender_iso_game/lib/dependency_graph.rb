class DependencyGraph
  def initialize(entities, meshes)
    @entities = entities
    @meshes = meshes
    
    
    
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
    
    @unbatched = Set.new # for entities that have not yet generated meshes
    
    @batches   = Hash.new  # single entities and instanced copies go here
                           # grouped by the mesh they use
    
  end
  
  # 
  # interface with core
  # 
  
  include RubyOF::Graphics
  def draw
    @batches.each do |mesh, batch|
      batch.update
    end
    
    
    lights = @entities.values.select{ |entity|  entity.is_a? BlenderLight }
    
    
    # ========================
    # render begin
    # ------------------------
    begin
      setup_lights_and_camera(lights)
      
      render_scene(lights)
      
    
    # clean up lights and camera whether there is an exception or not
    # but if there's an exception, you need to re-raise it
    # (can't just use 'ensure' here)
    rescue Exception => e 
      finish_lights_and_camera(lights)
      raise e
      
    else
      finish_lights_and_camera(lights)
      
    end
    # ------------------------
    # render end
    # ========================
  end
  
  
  def viewport_camera
    return @entities['viewport_camera']
  end
  
  def pack_entities
    @entities.to_a.collect{ |key, val|
      val.data_dump
    }
  end
  
  
  private
  
  
  def setup_lights_and_camera(lights)
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
    lights.each{ |light|  light.enable() }
  end
  
  def render_scene(lights)
    # 
    # render entities
    # 
    
    
    # render by batches
    # (RenderBatch automatically uses GPU instancing when necessary)
    @batches.each{|mesh, batch|  batch.draw }
    
    
    # 
    # render the sphere that represents the light
    # 
    
    lights.each do |light|
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
  
  def finish_lights_and_camera(lights)
    # 
    # disable lights
    # 
    
    # // turn off lighting //
    lights.each{ |light|  light.disable() }
    
    
    # 
    # teardown GL state
    # 
    
    ofDisableLighting()
    ofDisableDepthTest()
    
    # camera end
    @entities['viewport_camera'].end
  end
  
  class RenderBatch
    def initialize(mesh_obj)
      super() # set up state machine
      
      @mesh = mesh_obj.mesh
      @entity_list = [mesh_obj]
      
      
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
      reload_instancing_shaders()
    end
    
    def add(mesh_obj)
      @entity_list << mesh_obj
      
      if @entity_list.size > 1
        self.state = 'instanced_set'
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
        self.state = 'single'
      elsif @entity_list.size == 0
        self.state = 'empty'
      end
    end
    
    
    state_machine :state, :initial => 'single' do
      state 'empty' do # this state used in DependencyGraph#gc
        def draw()
          # no-op
        end
      end
      
      state 'single' do
        def draw()
          mesh_obj = @entity_list.first
          
          @mat1.begin()
            mesh_obj.node.transformGL()
            @mesh.draw()
            mesh_obj.node.restoreTransformGL()
          @mat1.end()
        end
      end
      
      state 'instanced_set' do
        def draw()
          # draw instanced (v4 - translation + z-rot, stored in texture)
          # NOTE: doesn't actually store z-rot right now, it's position only (normalized vector in RGB, with A channel for normalized magnitude)
          
          
          # collect up all the transforms
          positions = 
            @entity_list.collect do |mesh_obj|
              mesh_obj.node.position
            end
          
          
          # pack into image -> texture (which will be passed to shader)
          @instance_data.pack_positions(positions)
          
          # set uniforms
          @mat_instanced.setCustomUniformTexture(
            "position_tex", @instance_data.texture, 1
          )
            # but how is the primary texture used to color the mesh in the fragment shader bound? there is some texture being set to 'tex0' but I'm unsure where in the code that is actually specified
          
          @mat_instanced.setInstanceMagnitudeScale(
            InstancingBuffer::FLOAT_MAX
          )
          
          
          # draw all the instances using one draw call
          @mat_instanced.begin()
            @mesh.draw_instanced(@entity_list.size)
          @mat_instanced.end()
          
          
        end
        
      end
      
      
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
    
    
  end
  
  
  public
  
  
  
  # 
  # public interface with blender sync
  # 
  
  # TODO: reduce public interface - BlenderSync should only reference items by entity name, like a database, rather than accessing entity objects
  
  def gc(active: [])
    (@entities.keys - active - ['viewport_camera'])
    .each do |deleted_entity_name|
      entity = @entities.delete deleted_entity_name
      
      if entity.is_a? BlenderMesh
        @batches[entity.mesh].delete entity
      end
    end
    
    @batches.delete_if do |mesh, batch|
      batch.state == 'empty'
    end
  end
  
  # get existing entity if you have one, otherwise, create a new one
  def get_entity(type, name)
    entity = @entities[name]
    # NOTE: names in blender are unique 
    # TODO: what happens when an object is renamed?
    # TODO: what happens when an object is deleted?
    
    
    # create entity if one with that name does not already exist
    if entity.nil?
      klass = 
        case type
        when 'MESH'
          BlenderMesh
        when 'LIGHT'
          BlenderLight
        when 'CAMERA'
          # not yet implemented
          return nil
        end
      
      entity = klass.new
      
      entity.name = name
      
      @entities[name] = entity
      
      if entity.is_a? BlenderMesh
        @unbatched.add entity
      end
    end
    
    return entity
  end
  
  # def add_entity(entity)
  #   # nope. should not directly add entities.
  #   # depsgraph should be in charge of entire lifetime of entity,
  #   # including instantiation of instances.
  # end
  
  def update_entity_transform(entity, transform_data)
    entity.load_transform(transform_data)
    
    # TODO: UPDATE DEPSGRAPH WITH POSITIONS HERE
  end
  
  def update_entity_data(entity, type_string, obj_data)
    case type_string
    when 'MESH'
      # puts "mesh data"
      # p data
      
      mesh_name = obj_data['mesh_name']
      
      if @meshes.has_key? mesh_name
        # set the mesh based on existing linked copy
        mesh = @meshes[mesh_name]
        entity.mesh = mesh
      else
        # load data and then cache the underlying mesh
        # so linked copies point to the same data
        @meshes[mesh_name] = entity.load_data(obj_data).mesh
      end
      
      # assign mesh to batch
      if @unbatched.include? entity
        if @batches.has_key? entity.mesh
          @batches[entity.mesh].add entity
        else
          @batches[entity.mesh] = RenderBatch.new(entity)          
        end
        
        @unbatched.delete entity
      end
    
    when 'LIGHT'
      entity.tap do |light|
        light.disable()
        
        light.load_data(obj_data)
      end
      
    end
  end
  
  
  
  
  
  
  
  
  
  
  def create_new_entity(type_string)
    
  end
  
end
