
# order independent transparency render pipeline
class OIT_RenderPipeline
  
  def initialize
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
  end
  
  class Helper
    EMPTY_BLOCK = Proc.new{  }
    
    def initialize
      @shadow_pass      = EMPTY_BLOCK
      @opaque_pass      = EMPTY_BLOCK
      @transparent_pass = EMPTY_BLOCK
      @ui_pass          = EMPTY_BLOCK
    end
    
    def shadow_pass(&block)
      @shadow_pass = block
    end
    
    def opaque_pass(&block)
      @opaque_pass = block
    end
    
    def transparent_pass(&block)
      @transparent_pass = block
    end
    
    def ui_pass(&block)
      @ui_pass = block
    end
    
    def get_render_passes
      return @shadow_pass, @opaque_pass, @transparent_pass, @ui_pass
    end
    
  end
  
  class RenderContext
    include RubyOF::Graphics
    include Gl
    
    attr_reader :main_fbo, :transparency_fbo
    attr_reader :tex0, :tex1
    attr_reader :fullscreen_quad
    
    def initialize(window)
      settings = RubyOF::Fbo::Settings.new.tap do |s|
        s.width  = window.width
        s.height = window.height
        s.internalformat = GL_RGBA32F_ARB;
        # s.numSamples     = 0; # no multisampling
        s.useDepth       = true;
        s.useStencil     = false;
        s.depthStencilAsTexture = true;
        
        s.textureTarget  = GL_TEXTURE_RECTANGLE_ARB;
      end
      
      @main_fbo = 
        RubyOF::Fbo.new.tap do |fbo|
          settings.clone.tap{ |s|
            
            s.numColorbuffers = 1;
            
          }.yield_self{ |s| fbo.allocate(s) }
        end
      
      @transparency_fbo = 
        RubyOF::Fbo.new.tap do |fbo|
          settings.clone.tap{ |s|
            
            s.numColorbuffers = 2;
            
          }.yield_self{ |s| fbo.allocate(s) }
        end
      
      
      @tex0 = @transparency_fbo.getTexture(0)
      @tex1 = @transparency_fbo.getTexture(1)
      
      @fullscreen_quad = 
        @tex0.yield_self{ |texure|
          RubyOF::CPP_Callbacks.textureToMesh(texure, GLM::Vec3.new(0,0,0))
        }
      
    end
  end
  
  
  def update(window)
    @context = RenderContext.new(window)
    @shadow_cam = RubyOF::OFX::ShadowCamera.new()
    GC.start # force GC to clear old FBO data from RenderContext
  end
  
  
  
  COLOR_ZERO = RubyOF::FloatColor.rgba([0,0,0,0])
  COLOR_ONE  = RubyOF::FloatColor.rgba([1,1,1,1])
  
  include RubyOF::Graphics
  include Gl
  def draw(window, camera:nil, lights:nil, material:nil, &block)
    helper = Helper.new
    block.call(helper)
    
    passes = helper.get_render_passes
    @shadow_pass,@opaque_pass,@transparent_pass,@ui_pass = passes
    
    
    
    # ofEnableAlphaBlending()
    # # ^ doesn't seem to do anything, at least not right now
    
    # ofEnableBlendMode(:alpha)
    
    # ofBackground(10, 10, 10, 255);
    # // turn on smooth lighting //
    ofSetSmoothLighting(true)
    
    ofSetSphereResolution(32) # want higher resoultion than the default 20
    # ^ this is used to visualize the color and position of the lights
    
    
    
    # 
    # setup
    # 
    
    accumTex_i     = 0
    revealageTex_i = 1
    
    # TODO: regenerate FBOs and @fullscreen_quad when the window changes size. if you don't, then part of the view will be clipped off.
    @context ||= RenderContext.new(window)
    
    @compositing_shader ||= RubyOF::Shader.new
    
    
    
    num_lights = 10 # same as in bin/glsl/phong_anim_tex.frag
    shadow_map_size = 1024
    
    if @shadow_fbos.nil?
      RubyOF::Fbo::Settings.new.tap do |s|
        s.width  = shadow_map_size
        s.height = shadow_map_size
        
        s.internalformat = GL_RGBA16F_ARB;
        # TODO: switch internalFormat to GL_DEPTH_COMPONENT to save VRAM (currently getting error: FRAMEBUFFER_INCOMPLETE_ATTACHMENT)
        
        # s.numSamples     = 0; # no multisampling
        s.useDepth       = true;
        s.useStencil     = false;
        s.depthStencilAsTexture = true;
        s.depthStencilInternalFormat = GL_DEPTH_COMPONENT24;
        
        s.textureTarget  = GL_TEXTURE_2D;
        s.wrapModeHorizontal = GL_REPEAT;
        s.wrapModeVertical   = GL_REPEAT;
        s.minFilter = GL_NEAREST;
        s.maxFilter = GL_NEAREST;
        
        @shadow_fbos = Array.new(num_lights)
        @shadow_fbos.each_index do |i|
          @shadow_fbos[i] = 
          RubyOF::Fbo.new.tap do |fbo|
            s.clone.tap{ |s|
              
              s.numColorbuffers = 1;
              
            }.yield_self{ |s| fbo.allocate(s) }
          end
        end
      end
    end
    
    
    # 
    # update
    # 
    
    
    (PROJECT_DIR/'bin'/'glsl').tap do |shader_src_dir|
      @compositing_shader.live_load_glsl(
        shader_src_dir/'alpha_composite.vert',
        shader_src_dir/'alpha_composite.frag'
      ) do
        puts "alpha compositing shaders reloaded"
      end
    end
    
    @shadow_cam ||= RubyOF::OFX::ShadowCamera.new()
    # @shadow_cam.setSize(2**10, 2**10)
    @shadow_cam.setRange( 10, 150 )
    @shadow_cam.bias = 0.0001
    @shadow_cam.intensity = 0.6
    @shadow_cam.setAngle(30)
    
    @shadow_cam.position = lights.each.to_a[0].position
    @shadow_cam.orientation = lights.each.to_a[0].orientation
    
    
    # ---------------
    #   world space
    # ---------------
    
    
    # 
    # render shadow maps
    # 
    
    if @shadow_material.nil?
      @shadow_material = BlenderMaterial.new "OpenEXR vertex animation mat"
    end
    shader_src_dir = PROJECT_DIR/"bin/glsl"
    vert_shader_path = shader_src_dir/"animation_texture.vert"
    frag_shader_path = shader_src_dir/"shadow.frag"
    
    @shadow_material.load_shaders(vert_shader_path, frag_shader_path) do
      # on reload
      puts "reloaded shadow shaders"
    end
    
    # @shadow_pass.call(lights)
    
    
    
    
    # 
    # render shadows
    # 
    
    # puts "shadow simple depth pass"
    @shadow_cam.beginDepthPass()
      ofEnableDepthTest()
      # @shadow_pass.call(lights, @shadow_material)
      @opaque_pass.call()
      ofDisableDepthTest()
    @shadow_cam.endDepthPass()
    
    
    
    # 
    # render main buffers
    # (uses shadows)
    # 
    
    
    # McGuire, M., & Bavoil, L. (2013). Weighted Blended Order-Independent Transparency. 2(2), 20.
      # Paper assumes transparency encodes occlusion and demonstrates
      # how OIT works with colored smoke and clear glass.
      # 
      # Follow-up paper in 2016 demonstrates improvements,
      # including work with colored glass.
    
    # 
    # setup GL state
    # ofEnableDepthTest()
    ofEnableLighting() # // enable lighting //
    ofEnableDepthTest()
    
    lights.each{ |light|  light.enable() }
    
    lights.each do |light|
      
      attenuation_constant = 1;
      attenuation_linear = 0.000001;
      attenuation_quadratic = 0.000;
      
      light.setAttenuation(attenuation_constant,
                           attenuation_linear,
                           attenuation_quadratic)
      
      
      
      light.setAttenuation(1.0,  0.007,   0.0002)
      
      
      # constants from learnopengl,
      # which originally got them from ogre3d's wiki
      # src: https://learnopengl.com/Lighting/Light-casters
      
    end
    
    
    cam_view_matrix = camera.getModelViewMatrix()
    
    using_framebuffer @context.main_fbo do |fbo|
      # NOTE: must bind the FBO before you clear it in this way
      fbo.clearDepthBuffer(1.0) # default is 1.0
      fbo.clearColorBuffer(0, COLOR_ZERO)
      
      setShadowUniforms(material)
      
      using_camera camera do
        # puts "light on?: #{@lights[0]&.enabled?}" 
        
        @opaque_pass.call()
        
        
        # visualize lights
        # render colored spheres to represent lights
        lights.each do |light|
          light_pos   = light.position
          light_color = light.diffuse_color
          
          @light_material.tap do |mat|
            mat.emissive_color = light_color
            
            
            # light.draw
            mat.begin()
            ofPushMatrix()
              ofDrawSphere(light_pos.x, light_pos.y, light_pos.z, 0.1)
            ofPopMatrix()
            mat.end()
          end
        end
      end
    end
    
    
    blit_framebuffer :depth_buffer, @context.main_fbo => @context.transparency_fbo
    # RubyOF::CPP_Callbacks.blitDefaultDepthBufferToFbo(fbo)
    
    
    using_framebuffer @context.transparency_fbo do |fbo|
      # NOTE: must bind the FBO before you clear it in this way
      fbo.clearColorBuffer(accumTex_i,     COLOR_ZERO)
      fbo.clearColorBuffer(revealageTex_i, COLOR_ONE)
      
      RubyOF::CPP_Callbacks.enableTransparencyBufferBlending()
      
      setShadowUniforms(material)
      
      using_camera camera do
        @transparent_pass.call()
      end
      
      
      RubyOF::CPP_Callbacks.disableTransparencyBufferBlending()      
    end
    
    
    lights.each{ |light|  light.disable() }
    
    
    # teardown GL state
    ofDisableDepthTest()
    ofDisableLighting()
    
    # ----------------
    #   screen space
    # ----------------
    
    
    # RubyOF::CPP_Callbacks.clearDepthBuffer()
    # RubyOF::CPP_Callbacks.depthMask(true)
    
    # ofEnableBlendMode(:alpha)
    
    
    
    
    @context.main_fbo.draw(0,0)
    
    
    RubyOF::CPP_Callbacks.enableScreenspaceBlending()
    
    using_shader @compositing_shader do
      using_textures @context.tex0, @context.tex1 do
        @context.fullscreen_quad.draw()
      end
    end
    # draw_fbo_to_screen(@transparency_fbo, accumTex_i, revealageTex_i)
    # @transparency_fbo.draw(0,0)
    
    RubyOF::CPP_Callbacks.disableScreenspaceBlending()
    
    
    
    tex = @shadow_cam.getShadowMap()
    # tex.draw_wh(0,0,0, tex.width, tex.height)
    tex.draw_wh(1400,1300,0, 1024/4, 1024/4)
    # ^ ofxShadowCamera's buffer is the size of the window
    
    
    
    @ui_pass.call()
    
  end
  
  private
  
  def setShadowUniforms(material)
    material.setCustomUniformMatrix4f(
      "lightSpaceMatrix", @shadow_cam.getLightSpaceMatrix()
    )
    
    material.setCustomUniform1f(
      "u_shadowWidth", @shadow_cam.width
    )
    
    material.setCustomUniform1f(
      "u_shadowHeight", @shadow_cam.height
    )
    
    material.setCustomUniform1f(
      "u_shadowBias", @shadow_cam.bias
    )
    
    material.setCustomUniform1f(
      "u_shadowIntensity", @shadow_cam.intensity
    )
    
    
    
    material.setCustomUniformTexture(
      "shadow_tex", @shadow_cam.getShadowMap(), 4
    )
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
  
  def using_camera(camera) # &block
    exception = nil
    
    begin
      # camera begin
      camera.begin
      
      
      # (world space rendering block)
      yield
      
      
    rescue Exception => e 
      exception = e # supress exception so we can exit cleanly first
    ensure
      
      
      # camera end
      camera.end
      
      # after cleaning up, now throw the exception if needed
      unless exception.nil?
        raise exception
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
  

end
