class DependencyGraph
  def initialize()
    
    @viewport_camera = ViewportCamera.new
    
    @cameras = Hash.new
    
    
    @lights = Array.new
    @light_material = RubyOF::Material.new
    # ^ material used to visualize lights a small spheres in space.
    # color of this material may change for every light
    # so every light is rendered as a separate batch,
    # even though they all use the same sphere mesh.
    # (would need something like Unity's MaterialPropertyBlock to avoid this)
    # (for now, seems like creating the material is the expensive part anyway)
    
    
    # ^ materials used to visualize lights a small spheres in space
    # (basically just shows the color and position of each light)
    # (very important for debugging synchronization between RubyOF and blender)
    
    
    @mesh_objects    = Hash.new # {name => mesh }
    # @mesh_datablocks = Hash.new # {name => datablock }
    
    
    # @mesh_materials  = Hash.new # {name => material }
    # # ^ standard materials for individual meshes
    # # 
    # #   (materials are NOT entities, by which I mean
    # #    it is possible for a material and an entity
    # #    to have the same name. )
    # #  
    
    
    # actually, mesh objects and mesh datablocks can have overlaps in names too
    # but no two mesh datablocks can have the same name
    # and no two mesh objects can have the same name
    # (and I think the name of a mesh object can't overlap with say, a light?)
    
    
    
    
    # 
    # batch objects (for GPU instancing)
    # 
    
    @batches   = Array.new
      # # implement as a triple store
      # @batches = [
      #   [entity.mesh, entity.material,  RenderBatch.new]
      #   [entity.mesh, entity.material,  RenderBatch.new]
      #   [entity.mesh, entity.material,  RenderBatch.new]
      # ]
    
    
    
  end
  
  # 
  # interface with core
  # 
  
  include RubyOF::Graphics
  include Gl
  def draw(window)
    
    @batches.each do |mesh, mat, batch|
      # puts "batch id #{batch.__id__}"
      batch.update
    end
    
    
    
    accumTex_i     = 0
    revealageTex_i = 1
    
    
    
    opaque, transparent = partition_batches()
    
    
    
    camera_begin()
      opaque.each{|mesh, mat, batch|  batch.draw }
    camera_end()
    
    
    
    fbo = init_fbo(window) # => @transparency_fbo
    
    render_to_fbo(fbo, accumTex_i, revealageTex_i) do
      camera_begin()
        transparent.each{|mesh, mat, batch|  batch.draw }
      camera_end()
    end
    
    
    
    # init_compositing_shader()
    # live_reload_compositing_shader_glsl()
    
    draw_fbo_to_screen(fbo, accumTex_i, revealageTex_i)
  end
  
  
  private
    
    def partition_batches
      opaque, transparent = 
        @batches.partition do |mesh, mat, batch|
          mat.diffuse_color.a == 1
        end
      
      return opaque, transparent
    end
    
    def camera_begin
      # camera begin
      @viewport_camera.begin
      # 
      # setup GL state
      # 
      
      ofEnableDepthTest()
      ofEnableLighting() # // enable lighting //
      
      
      # ofEnableAlphaBlending()
      # # ^ doesn't seem to do anything, at least not right now
      
      # ofEnableBlendMode(:alpha)
      
      
      
      
      # 
      # enable lights
      # 
      
      # the position of the light must be updated every frame,
      # call enable() so that it can update itself
      @lights.each{ |light|  light.enable() }
      
      
      # =====================
      # (world space)
      # --------------------
    end
    
    def camera_end
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
      @viewport_camera.end
      
    end
    
    def init_fbo(window)
      if @transparency_fbo.nil?
        @transparency_fbo = 
          RubyOF::Fbo.new.tap do |fbo|
            # settings = 
            #   RubyOF::Fbo::Settings.new.tap do |s|
            #     s.width  = window.width#*0.5
            #     s.height = window.height#*0.5
            #     s.internalformat = GL_RGBA32F_ARB;
            #     # s.numSamples     = 0; # no multisampling
            #     s.useDepth       = true;
            #     # s.useStencil     = true;
            #     # # s.textureTarget  = ofGetUsingArbTex() ? GL_TEXTURE_RECTANGLE_ARB : GL_TEXTURE_2D;
                
            #     # s.textureTarget  = GL_TEXTURE_RECTANGLE_ARB;
                
                
            #     # s.numColorbuffers = 1;
            #     # # ^ create 2 textures using createAndAttachTexture(_settings.internalformat, i);
            #   end
            
            # fbo.allocate(settings)
            
            
            RubyOF::CPP_Callbacks.allocateFbo(fbo);
          end
      end
      
      
      return @transparency_fbo
    end
    
    def render_to_fbo(fbo, accumTex_i, revealageTex_i) # &block
      fbo.begin
      
      
      # NOTE: must bind the FBO before you clear it in this way
      
      # color_zero = RubyOF::FloatColor.rgba([0.5,0.5,0.7,0.8])
      # color_one  = RubyOF::FloatColor.rgba([1,1,1,1])
      
      # fbo.clearColorBuffer(accumTex_i,     color_zero)
      # fbo.clearColorBuffer(revealageTex_i, color_one)
      
      
      ofBackground(255,255,255, 255/2)
      
      # ofClear(1,1,0,1)
      
      # glDepthMask(GL_FALSE)
      # glEnable(GL_BLEND)
      # glBlendFunci(0, GL_ONE, GL_ONE) # summation
      # glBlendFunci(1, GL_ZERO, GL_ONE_MINUS_SRC_ALPHA) # product of (1 - a_i)
      # RubyOF::CPP_Callbacks.enableTransparencyBufferBlending()
      
      # ofDisableAlphaBlending()
      
      yield
      
      # ofEnableAlphaBlending()
      
      # RubyOF::CPP_Callbacks.disableTransparencyBufferBlending()
      
      
      fbo.end
      # unbindFramebuffer()
    end
    
    
    def draw_fbo_to_screen(fbo, accumTex_i, revealageTex_i)
      # blend the two textures into the framebuffer
      
      # glBlendEquation(GL_FUNC_ADD)
      # glBlendFunc(GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA)
      # RubyOF::CPP_Callbacks.enableScreenspaceBlending()
      
      # @compositing_shader.tap do |shader|
        # shader.setUniformTexture('accumTexture',     @accumTexture,     0)
        # shader.setUniformTexture('revealageTexture', @revealageTexture, 1)
        
        # shader.begin
          
          
          # # 
          # # v1
          # # 
          # tex = @transparency_fbo.getTexture(accumTex_i)
          # shader.setUniformTexture('accumTexture',     tex, 0)
          
          # # tex = @transparency_fbo.getTexture(revealageTex_i)
          # # shader.setUniformTexture('revealageTexture', tex, 1)
          
          # ofDrawRectangle(0,0,0, window.width, window.height)
          
          
          # 
          # v2
          # 
          
          fbo.draw(0,0)
        
        # shader.end
      # end
      
      # RubyOF::CPP_Callbacks.disableScreenspaceBlending()
      
    end
    
    
    
    def init_compositing_shader
      if @compositing_shader.nil?
        @compositing_shader = RubyOF::Shader.new
        @shader_timestamp = nil
      end
    end
    
    def live_reload_compositing_shader_glsl
      shader_src_dir = PROJECT_DIR/'bin'/'glsl'
      
      # dynamic reloading of compositing shader
      # (code copied from RenderBatch#reload_shaders)
      
      # p @shader_timestamp
      if @shader_timestamp.nil? || [shader_src_dir/'alpha_composite.vert', shader_src_dir/'alpha_composite.frag'].any?{|f| f.mtime > @shader_timestamp }
        
        puts "reloading alpha compositing shaders..."
        
        
        @compositing_shader.load_glsl(shader_src_dir/'alpha_composite')
        # ^ loads vertex shader AND fragment shader
        #   (.vert and .frag, same basename)
        
        # careful - these shaders don't go through the same pre-processing step as the ones in Material, so the '#define's don't apply here.
        # (the pre-processing is used by ofMaterial and defined in ofGLProgrammableRenderer.cpp)
        
        
        @shader_timestamp = Time.now
      end
      
    end
    
    
    def foo
      
      
      
      
      
      # puts ">>>>> batches: #{@batches.keys.size}"
      
      # t0 = RubyOF::Utils.ofGetElapsedTimeMicros
      
      
      # t1 = RubyOF::Utils.ofGetElapsedTimeMicros
      
      # dt = t1-t0
      # puts "time - batch update: #{dt.to_f / 1000} ms"
      
      
      # RubyOF::FloatColor.rgb([5, 1, 1]).tap do |c|
      #   print "color test => "
      #   puts c
      #   print "\n"
      # end
      
      
      
      # ========================
      # ------------------------
      # render begin
      # ------------------------
        
        
        # =====================
        # (world space)
        # --------------------
      begin
        
        
        
        # 
        # partition batches into opaque entities and transparent entities
        # 
        
        # 
        # draw opaque surfaces to framebuffer
        # 
        
        
        # transparent.each{|mesh, mat, batch|  batch.draw }
        
        # 
        # draw transparent surfaces to fbo
        # 
        # @accumTexture     ||= RubyOF::Texture.new
        # @revealageTexture ||= RubyOF::Texture.new
        
        
        
        
        
        
        # accumTexture     = RubyOF::Texture.new
          # TODO: ^ clear to vec4(0)
        # revealageTexture = RubyOF::Texture.new
          # TODO: ^ clear to float(1)
        
        # bindFramebuffer(@accumTexture, @revealageTexture)
        
        
        
        
        
      # clean up lights and camera whether there is an exception or not
      # but if there's an exception, you need to re-raise it
      # (can't just use 'ensure' here)
      
      rescue Exception => e 
        @exception = e # supress exception so we can exit cleanly first
      ensure
        
        
        # 
        # after cleaning up, now throw the exception if needed
        # 
        unless @exception.nil?
          e = @exception
          @exception = nil
          raise e
        end
        
      end
        
        
        
        # =======================
        # (screen space)
        # ----------------------
        
        
        # ^ fbo no longer exists here... why???
        
        
        # 
        # blend fbo (transparency data) with framebuffer
        # 
        
        
        
        
        
        # void ofFbo::updateTexture(int attachmentPoint)
        
          # Explicityl resolve MSAA render buffers into textures
          # \note if using MSAA, we will have rendered into a colorbuffer, not directly into the texture call this to blit from the colorbuffer into the texture so we can use the results for rendering, or input to a shader etc.
          # \note This will get called implicitly upon getTexture();
        
        
        
        
        # # 
        # # render the sphere that represents the light
        # # 
        
        # @lights.each do |light|
        #   light_pos   = light.position
        #   light_color = light.diffuse_color
          
        #   @light_material.tap do |mat|
        #     mat.emissive_color = light_color
            
            
        #     mat.begin()
        #     ofPushMatrix()
        #       ofDrawSphere(light_pos.x, light_pos.y, light_pos.z, 0.1)
        #     ofPopMatrix()
        #     mat.end()
        #   end
        # end
        
        
      # ------------------------
      # render end
      # ------------------------
      # ========================
    end
  
  public
  
  
  # def pack_entities
  #   @entities.to_a.collect{ |key, val|
  #     val.data_dump
  #   }
  # end
  
  
  
  # 
  # public interface with blender sync
  # 
  
  def viewport_camera
    return @viewport_camera
  end
  
  
  def gc(active: [])
    # TODO: update with camera object type when that is implemented
    # (currently the only camera that is synced is the viewport camera)
    
    [
      # ['camera',     (@cameras.keys - ['viewport_camera']) ],
      ['MESH',  @mesh_objects.keys],
      ['LIGHT', @lights.collect{ |x| x.name } ]
    ].each do |type, names|
      (names - active).each do |entity_name|
        delete entity_name, type # also removes empty batches
      end
    end
  end
  
  
  # DependencyGraph#add(o) returns self
  # comparison with other collections in Ruby:
  #   Array#<<(o) returns self
  #   Set#add(o) returns self
  #   Hash#store(k,v) AKA Hash#[]=(k,v) returns v
  # as DependencGrapy provides a Set-like interface, #add returns self
  def add(entity)
    # TODO: guard against adding the same entity twice
    
    
    # then perform additional processing based on type
    # (need to use strings to be symmetric with #delete)
    case entity.class::DATA_TYPE
    when 'MESH'
      # => adds datablock to collection (need to pull datablock by name)
      batch, i = find_batch_with_index @batches, entity
      
      batch.add entity
      
      
      # index by name
      @mesh_objects[entity.name] = entity
      
      
    when 'LIGHT'
      # => add to list of lights
      @lights << entity
    end
    
    
    return self
  end
  
  
  # #delete needs to take strings for types because due to
  # how case equality === works, you can't use ClassObjects
  def delete(entity_name, entity_type)
    puts "deleting: #{[entity_name, entity_type].inspect}"
    
    case entity_type
    when 'MESH'
      entity = @mesh_objects[entity_name]
      
      batch, i = find_batch_with_index @batches, entity
      
      # p batch
      
      batch.delete(entity)
      
      if batch.state == 'empty'
        # remove triple with mesh and material when batch empty
        # along with the batch itself
        @batches.delete_at i
      end
      
      
      # remove from index
      @mesh_objects.delete entity.name
      
      
    when 'LIGHT'
      @lights.delete_if{ |light|  light.name == entity_name }
    end
    
    
    return self
  end
  
  
  
  # assuming batches are stored as triples:
  private def find_batch_with_index(batches, entity)
    # find batch and index
    i = 
      batches.find_index{ |mesh, mat, batch| 
        entity.mesh.equal? mesh and entity.material.equal? mat
      }
    
    if i.nil?
      batch = RenderBatch.new()
      batches << [entity.mesh, entity.material, batch]
      
      i = batches.size-1
    end
    
    batch = batches[i].last # last element of triple is the batch itself
    
    return batch, i
  end
  
  
  
  # all methods starting with "fetch_" work as Hash#fetch
  # 
  # Return the value associated with the given key,
  # but if the key does not exist and a block is given,
  # return the output of the block instead
  # 
  # src: https://avdi.codes/why-and-how-to-use-rubys-hashfetch-for-default-values/
  
  # (actually, Hash#fetch also raises KeyError exception if key not found and no block given, but I don't do that here... hmmm maybe I need to support that?)
  # (Hash#fetch also supports a second argument as a default output)
  # (I should really implement this entire interface, otherwise it will cause confusion)
  
  def fetch_mesh_object(mesh_object_name)
    out = @mesh_objects[mesh_object_name]
    
    if out.nil? and block_given?
      return yield mesh_object_name
    else
      return out
    end
  end
  
  def fetch_mesh_datablock(mesh_name)
    out = @batches.collect{ |mesh, mat, batch| mesh  }.uniq
            .find{ |mesh|  mesh.name == mesh_name  }
    
    if out.nil? and block_given?
      return yield mesh_name
    else
      return out
    end
  end
  
  def fetch_light(light_name)
    out = @lights.find{ |light|  light.name == light_name }
    
    if out.nil? and block_given?
      return yield light_name
    else
      return out
    end
  end
  
  def fetch_material_datablock(material_name)
    out = @batches.collect{ |mesh, mat, batch| mat  }.uniq
            .find{ |mat|  mat.name == material_name  }
    
    if out.nil? and block_given?
      return yield material_name
    else
      return out
    end
  end
  
  
  
  
  # 
  # YAML serialization interface
  # 
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    
    # no need to store the batches: just regenerate them later
    # (NOTE: this may slow down reloading for scenes with many batches. need to check the performance on this later)
    
    data_hash = {
      'viewport_camera' => @viewport_camera,
      
      'lights' => @lights,
      'light_material' => @light_material,
      
      'mesh_objects'    => @mesh_objects,
      'mesh_datablocks' => @batches.collect{ |mesh, mat, batch| mesh  }.uniq,
      'mesh_materials'  => @batches.collect{ |mesh, mat, batch| mat   }.uniq,
      
      'batches'         => @batches.collect{ |mesh, mat, batch| batch }.uniq
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
    
    # @viewport_camera = ViewportCamera.new
    
    @cameras = Hash.new
    
    
    @lights = Array.new
    # @light_material = RubyOF::Material.new
    
    @mesh_objects    = Hash.new # {name => mesh }
    
    @batches   = Hash.new  # single entities and instanced copies go here
                           # grouped by the mesh they use
    
    
    
    
    
    
    
    
      @light_material = RubyOF::Material.new
      
    
    # all batches using GPU instancing are forced to refresh position on load
    @batches = Hash.new
      coder.map['batch_list'].each do |batch|
        @batches[batch.mesh.name] = batch
      end
    
    # @entities = Hash.new
    #   coder.map['entity_list'].each do |entity|
    #     @entities[entity.name] = entity
    #   end
    #   @batches.each_value do |batch|
    #     batch.each do |entity|
    #       @entities[entity.name] = entity
    #     end
    #   end
    
    # Hash#values returns copy, not reference
    # @meshes = @batches.values.collect{ |batch|  batch.mesh } 
    @lights = coder.map['lights']
  end
  
end
