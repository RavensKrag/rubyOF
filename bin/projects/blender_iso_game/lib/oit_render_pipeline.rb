
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
    # parameters
    # 
    
    accumTex_i     = 0
    revealageTex_i = 1
    
    
    # 
    # setup
    # 
    
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
    
    @shadow_vis_shader ||= RubyOF::Shader.new
    
    
    if @tex0.nil?
      @tex0 = @transparency_fbo.getTexture(accumTex_i)
      @tex1 = @transparency_fbo.getTexture(revealageTex_i)
      
      @fullscreen_quad = 
        @tex0.yield_self{ |texure|
          RubyOF::CPP_Callbacks.textureToMesh(texure, GLM::Vec3.new(0,0,0))
        }
    end
    
    
    
    
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
      
      @shadow_vis_shader.live_load_glsl(
        shader_src_dir/'alpha_composite.vert',
        shader_src_dir/'visualize_shadow_map.frag'
      ) do
        puts "shadow visualization shaders reloaded"
      end
    end
    
    
    
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
    
    @shadow_cam ||= RubyOF::Camera.new
    
    
    # currently low to the ground by the grid world segment, looking at the player cube and staircase, pointing into the grid. should not eclipse the entire scene, but doesn't correlate with any light's position either.
    @shadow_cam.tap do |cam|
      cam.position    = GLM::Vec3.new(17.03714942932129,
                                      -11.158864974975586,
                                      2.8595733642578125)
      cam.orientation = GLM::Quat.new(-0.7520553469657898,
                                      -0.6527585387229919,
                                      0.017086731269955635,
                                      0.08959237486124039)
      cam.fov         = 66.96208008631973
      cam.near_clip   = 0.01
      cam.far_clip    = 1000.0
    end
    
    # NOTE: current position, orientation, FOV, etc take from the viewport camera, moved into about the position of the area light. should be good enough for a first draft.
    
    
    # puts "\n"*5
    num_lights.times do |i|
      # only render shadows if the corresponding light exists and is enabled
      light = lights.each.to_a[i]
      # p light
      next if light.nil?
      # next if !light.enabled?
        # ^ This doesn't work because I haven't enabled the lights for this pass
        #   Need separate flag for shadows, but I'll do that later.
      
      # TODO: add flag to ofxDynamicLight for whether or not to draw shadows
      
      # puts "drawing shadow map #{i}"
      
      @shadow_fbos[i].tap do |x|
        using_framebuffer x do |fbo|
          # NOTE: must bind the FBO before you clear it in this way
          fbo.clearDepthBuffer(1.0) # default is 1.0
          fbo.clearColorBuffer(0, COLOR_ZERO)
          
          # get camera that represents the light's perspective
          light_camera = @shadow_cam
          
          # render from the perspective of the light
          using_camera light_camera do
            ofEnableDepthTest()
            @shadow_pass.call(lights, @shadow_material)
            ofDisableDepthTest()
          end
        end
      end
      
      
    end
    
    # @shadow_tex = @shadow_fbos[0].getDepthTexture()
    @shadow_tex = @shadow_fbos[0].getTexture(0)
    
    
    
    
    
    
    
    @shadow_simple ||= RubyOF::OFX::ShadowSimple.new()
    @shadow_simple.setRange( 10, 150 )
    @shadow_simple.bias = 0.01
    @shadow_simple.intensity = 0.8
    
    @shadow_simple.setLightPosition(lights.each.to_a[0].position)
    @shadow_simple.setLightOrientation(lights.each.to_a[0].orientation)
    
    # puts "shadow simple depth pass"
    @shadow_simple.beginDepthPass()
      ofEnableDepthTest()
      # @shadow_pass.call(lights, @shadow_material)
      @opaque_pass.call()
      ofDisableDepthTest()
    @shadow_simple.endDepthPass()
    
    
    
    
    
    # 
    # render main buffers
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
    
    using_framebuffer @main_fbo do |fbo|
      # NOTE: must bind the FBO before you clear it in this way
      fbo.clearDepthBuffer(1.0) # default is 1.0
      fbo.clearColorBuffer(0, COLOR_ZERO)
      
      setShadowUniforms(material, cam_view_matrix)
      
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
    
    
    blit_framebuffer :depth_buffer, @main_fbo => @transparency_fbo
    # RubyOF::CPP_Callbacks.blitDefaultDepthBufferToFbo(fbo)
    
    
    using_framebuffer @transparency_fbo do |fbo|
      # NOTE: must bind the FBO before you clear it in this way
      fbo.clearColorBuffer(accumTex_i,     COLOR_ZERO)
      fbo.clearColorBuffer(revealageTex_i, COLOR_ONE)
      
      RubyOF::CPP_Callbacks.enableTransparencyBufferBlending()
      
      setShadowUniforms(material, cam_view_matrix)
      
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
    
    
    
    
    using_shader @shadow_vis_shader do
      # using_textures @shadow_tex do
      #   ofPushMatrix()
      #   @fullscreen_quad.draw()
      #   ofPopMatrix()
      # end
      
      
      @shadow_tex.draw_wh(1400,950,0, 1024/4, 1024/4)
      # @shadow_tex.draw_wh(0,0,0, @shadow_tex.width, @shadow_tex.height)
    end
    tex = @shadow_simple.getFbo().getDepthTexture()
    # tex.draw_wh(0,0,0, tex.width, tex.height)
    tex.draw_wh(1400,1300,0, 1024/4, 1024/4)
    # ^ ofxShadowSimple's buffer is the size of the window
    
    
    
    @ui_pass.call()
    
  end
  
  private
  
  def setShadowUniforms(material, viewport_cam_view_matrix)
    lightCam = @shadow_simple.getLightCamera()
    
    # inverseCameraMatrix = GLM.inverse( viewport_cam_view_matrix );
    # shadowTransMatrix = inverseCameraMatrix * lightCam.getModelViewProjectionMatrix();
    
    # shadowTransMatrix = lightCam.getModelViewMatrix() * lightCam.getProjectionMatrix();
    
    # shadowTransMatrix = lightCam.getModelViewMatrix();
    
    
    # inverseCameraMatrix = GLM.inverse( viewport_cam_view_matrix );
    shadowTransMatrix = lightCam.getModelViewProjectionMatrix();
    
    
    material.setCustomUniformMatrix4f(
      "lightSpaceMatrix", shadowTransMatrix
    )
    
    material.setCustomUniform1f(
      "u_shadowWidth", @shadow_simple.width
    )
    
    material.setCustomUniform1f(
      "u_shadowHeight", @shadow_simple.height
    )
    
    material.setCustomUniform1f(
      "u_shadowBias", @shadow_simple.bias
    )
    
    material.setCustomUniform1f(
      "u_shadowIntensity", @shadow_simple.intensity
    )
    
    
    
    material.setCustomUniformTexture(
      "shadow_tex", @shadow_simple.getFbo().getDepthTexture(), 4
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
