
class RenderBatch
  include RubyOF::Graphics
  
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
    
    @vert_shader = shader_src_dir/"phong_instanced.vert"
    @frag_shader = shader_src_dir/"phong.frag"
    
    
    @instance_data = InstancingBuffer.new(max_instances: 4096)
    
    @@identity_transform_data ||=
      InstancingBuffer.new(max_instances: 1).tap do |buffer|
        node = RubyOF::Node.new
        
        buffer.pack_all_transforms( [node] )
        
      end
  end
  
  def update
    case @state
    when 'single'
      reload_shaders(@vert_shader, @frag_shader) do
        # on reload
        puts "instancing shaders reloaded" 
      end
      
    when 'instanced_set'
      reload_shaders(@vert_shader, @frag_shader) do
        # on reload
        puts "instancing shaders reloaded" 
      end
      
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
  
  # Material uniforms must be set before material is bound,
  # so material binding can not happen outside the case statement,
  # even though it is something that must happen for all cases.
  def draw()
    case @state
    when 'empty'
      # no-op
    when 'single'
      @mat.setCustomUniformTexture(
        "transform_tex", @@identity_transform_data.texture, 1
      )
      
      using_material @mat do
        mesh_obj = @entity_list.first
        
        mesh_obj.node.transformGL()
        @mesh.draw_instanced(1)
        mesh_obj.node.restoreTransformGL()
      end
      
    when 'instanced_set'
      # draw instanced (v4.2 - 4x4 full transform matrix in texture)
      
      # set uniforms
      @mat.setCustomUniformTexture(
        "transform_tex", @instance_data.texture, 1
      )
        # but how is the primary texture used to color the mesh in the fragment shader bound? there is some texture being set to 'tex0' but I'm unsure where in the code that is actually specified
      
      
      # draw all the instances using one draw call
      using_material @mat do
        @mesh.draw_instanced(@entity_list.size)
      end
      
    end
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
  
  def size
    @entity_list.size
  end
  
  
  private
  
  
  # TODO: move this function into the appropriate material class
  
  # Reload specified shaders if necessary and return new timestamp.
  # If the shaders were not reloaded, timestamp remains unchanged.
  def reload_shaders(vert_shader_path, frag_shader_path) # &block
    # load shaders if they have never been loaded before,
    # or if the files have been updated
    if @shader_timestamp.nil? || [vert_shader_path, frag_shader_path].any?{|f| f.mtime > @shader_timestamp }
      
      
      vert_shader = File.readlines(vert_shader_path).join("\n")
      frag_shader = File.readlines(frag_shader_path).join("\n")
      
      @mat.setVertexShaderSource vert_shader
      @mat.setFragmentShaderSource frag_shader
      
      puts "reloading vertex and frag shaders for #{self.class}"
      
      bShadersLoaded = @mat.forceShaderRecompilation()
      
      raise "ERROR: One of the GLSL shaders in the material failed to load. Check logs for details." unless bShadersLoaded
      
      # NOTE: the shader source strings *will* be effected by the shader preprocessing pipeline in ofShader.cpp
      
      
      @shader_timestamp = Time.now
      
      yield if block_given?
    end
  end
  
  # get all the nodes marked 'dirty' and update their positions in the instance data texture. only need to do this when @state == 'instanced_set'
  def update_packed_entity_positions
    t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    nodes = @entity_list.collect{|entity| entity.node}
    
    t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    dt = t1-t0
    # puts "time - gather mesh entities: #{dt.to_f / 1000} ms"
    
    
    @instance_data.pack_all_transforms(nodes)
  end
end