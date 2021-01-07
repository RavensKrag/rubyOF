
class RenderBatch
  # NOTE: can't use state machine because it requires super() in initialize
  # and I need to bypass initialize() when loading from YAML
  attr_reader :state # read only: state is always managed interally
  attr_reader :mesh  # read only: once you assign a mesh, it's done
  
  def initialize()
    @mesh = nil
    @mat1 = nil
    
    @entity_list = nil
    
    @state = 'empty' # ['single', 'instanced_set', 'empty']
    
    setup()
  end
  
  # setup is called by the YAML loader, and bypasses initialize
  def setup()
    @batch_dirty = false
    
    # @mat1 and @mat_instanced should have the same apperance
    @mat_instanced = RubyOF::OFX::InstancingMaterial.new
    
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
      
      # NOTE: If this is the style I eventually settle on, the dirty flag should ideally be moved to a single flag on the entire batch, rather than one flag on each entity.
      
      if @batch_dirty or @entity_list.any?{|entity| entity.dirty }
        update_packed_entity_positions
        
        # update_instanced_material_properties
        #   # ^ calling this on update seems to cause segfault???
        #   # (was getting many weird segfaults before. I think it was a synchronization with Blender problem, but I'll keep this note here just in case.)
        
        @entity_list.each{|entity| entity.dirty = false }
        @batch_dirty = false
      end
      
      
    end
  end
  
  def add(mesh_obj)
    # TODO: may want to double-check that the entity being added uses the mesh that is managed by this batch
    
    case @state
    when 'empty'
      @mesh = mesh_obj.mesh
      @mat1 = mesh_obj.material
      
      @entity_list = [mesh_obj]
      
      @state = 'single'
    else
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
      
      update_instanced_material_properties
      
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
  
  def update_instanced_material_properties
    @mat_instanced.diffuse_color = @mat1.diffuse_color
    @mat_instanced.shininess = @mat1.shininess
  end
  
  # get all the nodes marked 'dirty' and update their positions in the instance data texture. only need to do this when @state == 'instanced_set'
  def update_packed_entity_positions
    t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    nodes = @entity_list.collect{|entity| entity.node}
    
    t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    dt = t1-t0
    puts "time - gather mesh entities: #{dt.to_f / 1000} ms"
    
    
    @instance_data.pack_all_transforms(nodes)
  end
end
