
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
      @opaque_pass      = EMPTY_BLOCK
      @transparent_pass = EMPTY_BLOCK
      @ui_pass          = EMPTY_BLOCK
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
      return @opaque_pass, @transparent_pass, @ui_pass
    end
    
  end
  
  
  
  COLOR_ZERO = RubyOF::FloatColor.rgba([0,0,0,0])
  COLOR_ONE  = RubyOF::FloatColor.rgba([1,1,1,1])
  
  include RubyOF::Graphics
  include Gl
  def draw(window, camera:nil, lights:nil, &block)
    helper = Helper.new
    block.call(helper)
    
    @opaque_pass,@transparent_pass,@ui_pass = helper.get_render_passes
    
    
    
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
      ) do
        puts "alpha compositing shaders reloaded"
      end
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
    
    # 
    # setup GL state
    # ofEnableDepthTest()
    ofEnableLighting() # // enable lighting //
    ofEnableDepthTest()
    
    lights.each{ |light|  light.enable() }
    
    
    
    using_framebuffer @main_fbo do |fbo|
      # NOTE: must bind the FBO before you clear it in this way
      fbo.clearDepthBuffer(1.0) # default is 1.0
      fbo.clearColorBuffer(0, COLOR_ZERO)
      
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
    
    
    
    
    
    @ui_pass.call()
    
  end
  
  private
  
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
