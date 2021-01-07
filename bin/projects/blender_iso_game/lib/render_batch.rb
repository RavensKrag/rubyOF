
class RenderBatch
  # NOTE: can't use state machine because it requires super() in initialize
  # and I need to bypass initialize() when loading from YAML
  attr_reader :state # read only: state is always managed interally
  attr_reader :mesh  # read only: once you assign a mesh, it's done
  
  def initialize()
    @mesh = nil
    @mat = nil # RubyOF::OFX::InstancingMaterial.new
    
    @entity_list = nil
    
    @state = 'empty' # ['single', 'instanced_set', 'empty']
    
    setup()
  end
  
  # setup is called by the YAML loader, and bypasses initialize
  def setup()
    @batch_dirty = false
    
    
    @shader_timestamp = nil
    
    shader_src_dir = PROJECT_DIR/"bin/glsl"
    
    @shader_paths = {
      :vert_instanced => shader_src_dir/"phong_instanced.vert",
      :vert_single    => shader_src_dir/"phong.vert",
      :frag           => shader_src_dir/"phong.frag"
    }
    
    @instance_data = InstancingBuffer.new
  end
  
  def update
    case @state
    when 'single'
      reload_single_shaders()
      
    when 'instanced_set'
      reload_instancing_shaders()
      
      # NOTE: If this is the style I eventually settle on, the dirty flag should ideally be moved to a single flag on the entire batch, rather than one flag on each entity.
      
      if @batch_dirty or @entity_list.any?{|entity| entity.dirty }
        update_packed_entity_positions
        
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
      @mat  = mesh_obj.material
      
      @entity_list = [mesh_obj]
      
      transition_to 'single'
    else
      @entity_list << mesh_obj
      
      if @entity_list.size > 1
        transition_to 'instanced_set'
        
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
      transition_to 'single'
    elsif @entity_list.size == 0
      transition_to 'empty'
    end
    
    @batch_dirty = true
  end
  
  def draw()
    case @state
    when 'empty'
      # no-op
    when 'single'
      mesh_obj = @entity_list.first
      
      @mat.begin()
        mesh_obj.node.transformGL()
        @mesh.draw()
        mesh_obj.node.restoreTransformGL()
      @mat.end()
    when 'instanced_set'
      # draw instanced (v4.2 - 4x4 full transform matrix in texture)
      
      # set uniforms
      @mat.setCustomUniformTexture(
        "transform_tex", @instance_data.texture, 1
      )
        # but how is the primary texture used to color the mesh in the fragment shader bound? there is some texture being set to 'tex0' but I'm unsure where in the code that is actually specified
      
      # @mat.setInstanceMagnitudeScale(
      #   InstancingBuffer::FLOAT_MAX
      # )
      
      # @mat.setInstanceTextureWidth(
      #   @instance_data.width
      # )
      
      
      # draw all the instances using one draw call
      @mat.begin()
        @mesh.draw_instanced(@entity_list.size)
      @mat.end()
      
    end
    # no-op
  end
  
  private def transition_to(new_state)
    # invalidate shaders when switching states to force reload
    
    case new_state
    when 'single'
      @shader_timestamp = nil
    when 'instanced_set'
      @shader_timestamp = nil
    end
    
    
    @state = new_state
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
  
  # Reload specified shaders if necessary and return new timestamp.
  # If the shaders were not reloaded, timestamp remains unchanged.
  def reload_shaders(vert_shader_path, frag_shader_path)
    # load shaders if they have never been loaded before,
    # or if the files have been updated
    if @shader_timestamp.nil? || [vert_shader_path, frag_shader_path].any?{|f| f.mtime > @shader_timestamp }
      
      
      vert_shader = File.readlines(vert_shader_path).join("\n")
      frag_shader = File.readlines(frag_shader_path).join("\n")
      
      @mat.setVertexShaderSource vert_shader
      @mat.setFragmentShaderSource frag_shader
      
      # NOTE: the shader source strings *will* be effected by the shader preprocessing pipeline in ofShader.cpp
      
      
      @shader_timestamp = Time.now
    end
  end
  
  def reload_single_shaders
    reload_shaders(@shader_paths[:vert_single], @shader_paths[:frag]) do
      # on reload
      puts "single object shaders reloaded" 
    end
  end
  
  def reload_instancing_shaders
    reload_shaders(@shader_paths[:vert_instanced], @shader_paths[:frag]) do
      # on reload
      puts "instancing shaders reloaded" 
    end
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
