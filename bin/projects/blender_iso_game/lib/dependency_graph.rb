class DependencyGraph
  
  COLOR_ZERO = RubyOF::FloatColor.rgba([0,0,0,0])
  COLOR_ONE  = RubyOF::FloatColor.rgba([1,1,1,1])
  
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
    
    
    # ofEnableAlphaBlending()
    # # ^ doesn't seem to do anything, at least not right now
    
    # ofEnableBlendMode(:alpha)
    
    
    
    # 
    # parameters
    # 
    
    accumTex_i     = 0
    revealageTex_i = 1
    
    
    # 
    # setup
    # 
    
    settings = 
      RubyOF::Fbo::Settings.new.tap do |s|
        s.width  = window.width
        s.height = window.height
        s.internalformat = GL_RGBA32F_ARB;
        # s.numSamples     = 0; # no multisampling
        s.useDepth       = true;
        s.useStencil     = false;
        s.depthStencilAsTexture = true;
        
        s.textureTarget  = GL_TEXTURE_RECTANGLE_ARB;
        
        @main_fbo ||= 
          RubyOF::Fbo.new.tap do |fbo|
            s.clone.tap{ |s|
              
              s.numColorbuffers = 1;
              
            }.yield_self{ |s| fbo.allocate(s) }
          end
        
        @transparency_fbo ||= 
          RubyOF::Fbo.new.tap do |fbo|
            s.clone.tap{ |s|
              
              s.numColorbuffers = 2;
              
            }.yield_self{ |s| fbo.allocate(s) }
          end
        
      end
    
    @compositing_shader ||= RubyOF::Shader.new
    
    
    if @tex0.nil?
      @tex0 = @transparency_fbo.getTexture(accumTex_i)
      @tex1 = @transparency_fbo.getTexture(revealageTex_i)
      
      @fullscreen_quad = 
        @tex0.yield_self{ |texure|
          RubyOF::CPP_Callbacks.textureToMesh(texure, GLM::Vec3.new(0,0,0))
        }
    end
    
    
    # 
    # update
    # 
    
    
    (PROJECT_DIR/'bin'/'glsl').tap do |shader_src_dir|
      @compositing_shader.live_load_glsl(
        shader_src_dir/'alpha_composite.vert',
        shader_src_dir/'alpha_composite.frag'
      )
    end
    
    
    
    # ---------------
    #   world space
    # ---------------
    
    
    # McGuire, M., & Bavoil, L. (2013). Weighted Blended Order-Independent Transparency. 2(2), 20.
      # Paper assumes transparency encodes occlusion and demonstrates
      # how OIT works with colored smoke and clear glass.
      # 
      # Follow-up paper in 2016 demonstrates improvements,
      # including work with colored glass.
    
    
    ofEnableDepthTest()
    
    opaque, transparent = 
      @batches.partition do |mesh, mat, batch|
        mat.diffuse_color.a == 1
      end
    
    
    using_framebuffer @main_fbo do |fbo|
      # NOTE: must bind the FBO before you clear it in this way
      fbo.clearDepthBuffer(1.0) # default is 1.0
      fbo.clearColorBuffer(0, COLOR_ZERO)
      
      lights_and_camera do
        opaque.each{|mesh, mat, batch|  batch.draw }
        
        visualize_lights()
      end
    end
    
    
    blit_framebuffer :depth_buffer, @main_fbo => @transparency_fbo
    # RubyOF::CPP_Callbacks.blitDefaultDepthBufferToFbo(fbo)
    
    
    using_framebuffer @transparency_fbo do |fbo|
      # NOTE: must bind the FBO before you clear it in this way
      fbo.clearColorBuffer(accumTex_i,     COLOR_ZERO)
      fbo.clearColorBuffer(revealageTex_i, COLOR_ONE)
      
      RubyOF::CPP_Callbacks.enableTransparencyBufferBlending()
      
      lights_and_camera do
        transparent.each{|mesh, mat, batch|  batch.draw }
      end
      
      RubyOF::CPP_Callbacks.disableTransparencyBufferBlending()      
    end
    
    ofDisableDepthTest()
    
    
    # ----------------
    #   screen space
    # ----------------
    
    
    # RubyOF::CPP_Callbacks.clearDepthBuffer()
    # RubyOF::CPP_Callbacks.depthMask(true)
    
    # ofEnableBlendMode(:alpha)
    
    @main_fbo.draw(0,0)
    
    
    RubyOF::CPP_Callbacks.enableScreenspaceBlending()
    
    using_shader @compositing_shader do
      using_textures @tex0, @tex1 do
        @fullscreen_quad.draw()
      end
    end
    # draw_fbo_to_screen(@transparency_fbo, accumTex_i, revealageTex_i)
    # @transparency_fbo.draw(0,0)
    
    RubyOF::CPP_Callbacks.disableScreenspaceBlending()
    
    
  end
  
  
  private
    
    # TODO: add exception handling here, so gl state set by binding shader and textures doesn't leak
    def using_shader(shader) # &block
      shader.begin
      
      yield shader
      
      shader.end
    end
    
    # TODO: add exception handling here, so gl state set by binding shader and textures doesn't leak
    def using_textures(*texture_list)
      texture_list.each_with_index do |tex,i|
        tex.bind(i) unless tex.nil?
      end
      
      yield *texture_list
      
      texture_list.each_with_index do |tex,i|
        tex.unbind(i) unless tex.nil?
      end
    end
    
    def blit_framebuffer(buffer_name, hash={})
      src = hash.keys.first
      dst = hash.values.first
      
      buffer_flag = 
        case buffer_name
        when :color_buffer
          0b01
        when :depth_buffer
          0b10
        when :both
          0b11
        else
          0x00
        end
      
      RubyOF::CPP_Callbacks.copyFramebufferByBlit__cpp(
        src, dst, buffer_flag
      )
    end
    
    def lights_and_camera # &block
      exception = nil
      
      begin
        # camera begin
        @viewport_camera.begin
        
        # setup GL state
        # ofEnableDepthTest()
        ofEnableLighting() # // enable lighting //
        
        
        # enable lights
          # the position of the light must be updated every frame,
          # call enable() so that it can update itself
        @lights.each{ |light|  light.enable() }
        
        
        # (world space rendering block)
        yield
        
        
      rescue Exception => e 
        exception = e # supress exception so we can exit cleanly first
      ensure
        # disable lights
          # // turn off lighting //
        @lights.each{ |light|  light.disable() }
        
        # teardown GL state
        ofDisableLighting()
        # ofDisableDepthTest()
        
        # camera end
        @viewport_camera.end
        
        # after cleaning up, now throw the exception if needed
        unless exception.nil?
          raise exception
        end
        
      end
    end
    
    # render colored spheres to represent lights
    def visualize_lights
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
    
    # TODO: add exception handling here, so gl state set by using the FBO / setting special blending modes doesn't leak
    def using_framebuffer fbo # &block
      fbo.begin
        fbo.activateAllDrawBuffers() # <-- essential for using mulitple buffers
        # ofEnableDepthTest()
        
        
        # glDepthMask(GL_FALSE)
        # glEnable(GL_BLEND)
        # glBlendFunci(0, GL_ONE, GL_ONE) # summation
        # glBlendFunci(1, GL_ZERO, GL_ONE_MINUS_SRC_ALPHA) # product of (1 - a_i)
        # RubyOF::CPP_Callbacks.enableTransparencyBufferBlending()
        
          yield fbo
        
        # RubyOF::CPP_Callbacks.disableTransparencyBufferBlending()
        
        # ofDisableDepthTest()
      fbo.end
    end
    
    # void ofFbo::updateTexture(int attachmentPoint)
    
      # Explicitly resolve MSAA render buffers into textures
      # \note if using MSAA, we will have rendered into a colorbuffer, not directly into the texture call this to blit from the colorbuffer into the texture so we can use the results for rendering, or input to a shader etc.
      # \note This will get called implicitly upon getTexture();
    
  
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
