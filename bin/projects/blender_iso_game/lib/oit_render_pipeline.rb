
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
    
    
    
    # material invokes shaders
    @material = BlenderMaterial.new "OpenEXR vertex animation mat"
    # @material.diffuse_color = RubyOF::FloatColor.rgba([1,1,1,1])
    # @material.specular_color = RubyOF::FloatColor.rgba([0,0,0,0])
    # @material.emissive_color = RubyOF::FloatColor.rgba([0,0,0,0])
    # @material.ambient_color = RubyOF::FloatColor.rgba([0.2,0.2,0.2,0])
    
    
    @compositing_shader = RubyOF::Shader.new
  end
  
  class RenderContext
    include RubyOF::Graphics
    include Gl
    
    attr_reader :main_fbo, :transparency_fbo
    attr_reader :accumlation_index,    :revealage_index
    attr_reader :accumulation_tex, :revealage_tex
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
      
      
      
      @accumlation_index = 0
      @revealage_index   = 1
      
      @accumulation_tex = @transparency_fbo.getTexture(@accumlation_index)
      @revealage_tex    = @transparency_fbo.getTexture(@revealage_index)
      
      @fullscreen_quad = 
        @accumulation_tex.yield_self{ |texure|
          RubyOF::CPP_Callbacks.textureToMesh(texure, GLM::Vec3.new(0,0,0))
        }
      
    end
  end
  
  
  def on_window_resized(window, lights)
    @context = RenderContext.new(window)
    lights.each{|l| l.update }
    GC.start # force GC to clear old FBO data from RenderContext
  end
  
  
  
  COLOR_ZERO = RubyOF::FloatColor.rgba([0,0,0,0])
  COLOR_ONE  = RubyOF::FloatColor.rgba([1,1,1,1])
  
  include RubyOF::Graphics
  include Gl
  def draw(window, world, &block)
    ui_pass = block
    
    # 
    # setup
    # 
    
    @context ||= RenderContext.new(window)
    
    # ofEnableAlphaBlending()
    # # ^ doesn't seem to do anything, at least not right now
    
    # ofEnableBlendMode(:alpha)
    
    # ofBackground(10, 10, 10, 255);
    # // turn on smooth lighting //
    ofSetSmoothLighting(true)
    
    
    # 
    # update
    # 
    
    (PROJECT_DIR/'bin'/'glsl').tap do |shader_src_dir|
      # 
      # 3d rendering uber-material with GPU instancing
      # 
      vert_shader_path = shader_src_dir/"animation_texture.vert"
      
      # frag_shader_path = shader_src_dir/"phong_test.frag"
      frag_shader_path = shader_src_dir/"phong_anim_tex.frag"
      
      @material.load_shaders(vert_shader_path, frag_shader_path) do
        # on shader reload
        
      end
      
      # 
      # compositing shader for OIT
      # 
      @compositing_shader.live_load_glsl(
        shader_src_dir/'alpha_composite.vert',
        shader_src_dir/'alpha_composite.frag'
      ) do
        puts "alpha compositing shaders reloaded"
      end
    end
    
    
    # 
    # render shadow maps
    # 
    world.lights
    .select{|light| light.casts_shadows? }
    .each do |light|
      render_shadow_map(world, light)
    end
    
    # 
    # render main buffers
    # (uses shadows)
    # 
    
    # t20 = RubyOF::TimeCounter.now
    # t21 = RubyOF::TimeCounter.now
    
    # setup GL state
    ofEnableLighting() # // enable lighting //
    ofEnableDepthTest()
    
    world.lights.each{ |light|  light.enable() }
    
    shadow_casting_light = world.lights.select{|l| l.casts_shadows? }.first
    
      render_opaque_pass(
        world, shadow_casting_light, @context.main_fbo
      )
      
      blit_framebuffer(:depth_buffer,
                       @context.main_fbo => @context.transparency_fbo)
      # RubyOF::CPP_Callbacks.blitDefaultDepthBufferToFbo(fbo)
      
      render_transparent_pass(
        world, shadow_casting_light, @context.transparency_fbo
      )
    
    world.lights.each{ |light|  light.disable() }
    
    # teardown GL state
    ofDisableDepthTest()
    ofDisableLighting()
    
    
    # 
    # compositing
    # 
    @context.main_fbo.draw(0,0)
    
    RubyOF::CPP_Callbacks.enableScreenspaceBlending()
    
    using_shader @compositing_shader do
      using_textures @context.accumulation_tex, @context.revealage_tex do
        @context.fullscreen_quad.draw()
      end
    end
    
    RubyOF::CPP_Callbacks.disableScreenspaceBlending()
    
    
    # 
    # UI rendering
    # 
    render_diagetic_ui(world.camera, world.lights) # 3D world space
    ui_pass.call(shadow_casting_light) # 2D viewport space
  end
  
  private
  
  
  # 
  # rendering stages
  # 
  
  # render shadow maps using ofxShadowCamera
  def render_shadow_map(world, light)
    # TODO: need to handle opaque shadow casters separately from transparent shadow casters. opaque shadow casters merely block light, but transparent shadow casters modify the color of the light while also reducing its intensity.
    
    
    # if @shadow_material.nil?
    #   @shadow_material = BlenderMaterial.new "OpenEXR vertex animation mat"
    # end
    # shader_src_dir = PROJECT_DIR/"bin/glsl"
    # vert_shader_path = shader_src_dir/"animation_texture.vert"
    # frag_shader_path = shader_src_dir/"shadow.frag"
    
    # @shadow_material.load_shaders(vert_shader_path, frag_shader_path) do
    #   # on reload
    #   puts "reloaded shadow shaders"
    # end
    
    # Code above is from old style of shadow rendering. Currently, FBOs etc for shadows are contained in ofxShadowCamera. For shaders, we use the normal shaders from the opaque pass. Could potentially use different shaders to only draw depth to save time, but I can't quite figure out how to bind just the depth buffer.
    
    # puts "shadow simple depth pass"
    light.update
    light.shadow_cam.beginDepthPass()
      ofEnableDepthTest()
        world.batches.each do |b|
          # set uniforms
          @material.setCustomUniformTexture(
            "vert_pos_tex",  b[:mesh_data][:textures][:positions], 1
          )
          
          @material.setCustomUniformTexture(
            "vert_norm_tex", b[:mesh_data][:textures][:normals], 2
          )
          
          @material.setCustomUniformTexture(
            "entity_tex", b[:entity_data][:texture], 3
          )
          
          @material.setCustomUniform1f(
            "transparent_pass", 0
          )
          
          # draw using GPU instancing
          using_material @material do
            instance_count = b[:entity_data][:pixels].height.to_i
            b[:geometry].draw_instanced instance_count
          end
        end
      ofDisableDepthTest()
    light.shadow_cam.endDepthPass()
    
    
    # TODO: fix extent of spotlight shadows.
      # shadows can extend beyond the edge of the cone of the spotlight, because the shadow camera is really using a frustrum (pyramid) instead of the cone of the spotlight. thus, there are conditions where the shadow sticks out beyond the boundary of the spotlight, which is not physical behavior.
    
  end
  
  
  # opaque pass and transparent pass as described in the paper below:
  # 
  # McGuire, M., & Bavoil, L. (2013). Weighted Blended Order-Independent Transparency. 2(2), 20.
    # Paper assumes transparency encodes occlusion and demonstrates
    # how OIT works with colored smoke and clear glass.
    # 
    # Follow-up paper in 2016 demonstrates improvements,
    # including work with colored glass.
  
  def render_opaque_pass(world, shadow_casting_light, opaque_pass_fbo)
    using_framebuffer opaque_pass_fbo do |fbo|
      # NOTE: must bind the FBO before you clear it in this way
      fbo.clearDepthBuffer(1.0) # default is 1.0
      fbo.clearColorBuffer(0, COLOR_ZERO)
      
      using_camera world.camera do
        # puts "light on?: #{@lights[0]&.enabled?}" 
        
        if shadow_casting_light.nil?
          @material.setCustomUniform1f(
            "u_useShadows", 0
          )
        else
          shadow_casting_light.setShadowUniforms(@material)
        end
        
        # NOTE: transform matrix for light space set in oit_render_pipeline before any objects are drawn
        world.batches.each do |b|
          # set uniforms
          @material.setCustomUniformTexture(
            "vert_pos_tex",  b[:mesh_data][:textures][:positions], 1
          )
          
          @material.setCustomUniformTexture(
            "vert_norm_tex", b[:mesh_data][:textures][:normals], 2
          )
          
          @material.setCustomUniformTexture(
            "entity_tex", b[:entity_data][:texture], 3
          )
          
          @material.setCustomUniform1f(
            "transparent_pass", 0
          )
          
          # draw using GPU instancing
          using_material @material do
            instance_count = b[:entity_data][:pixels].height.to_i
            b[:geometry].draw_instanced instance_count
          end
        end
        
        # glCullFace(GL_BACK)
        # glDisable(GL_CULL_FACE)
        
      end
    end
    
  end
  
  def render_transparent_pass(world, shadow_casting_light, transparent_pass_fbo)
    using_framebuffer transparent_pass_fbo do |fbo|
      # NOTE: must bind the FBO before you clear it in this way
      fbo.clearColorBuffer(@context.accumlation_index,  COLOR_ZERO)
      fbo.clearColorBuffer(@context.revealage_index,    COLOR_ONE)
      
      RubyOF::CPP_Callbacks.enableTransparencyBufferBlending()
      
      if shadow_casting_light.nil?
        @material.setCustomUniform1f(
          "u_useShadows", 0
        )
      else
        shadow_casting_light.setShadowUniforms(@material)
      end
      
      # NOTE: transform matrix for light space set in oit_render_pipeline before any objects are drawn
      using_camera world.camera do
        world.batches.each do |b|
          # set uniforms
          @material.setCustomUniformTexture(
            "vert_pos_tex",  b[:mesh_data][:textures][:positions], 1
          )
          
          @material.setCustomUniformTexture(
            "vert_norm_tex", b[:mesh_data][:textures][:normals], 2
          )
          
          @material.setCustomUniformTexture(
            "entity_tex", b[:entity_data][:texture], 3
          )
          
          @material.setCustomUniform1f(
            "transparent_pass", 1
          )
          
          # draw using GPU instancing
          using_material @material do
            instance_count = b[:entity_data][:pixels].height.to_i
            b[:geometry].draw_instanced instance_count
          end
        end
        
        # while time traveling, render the trails of moving objects
        if world.transport.time_traveling?
          
        end
      end
      
      
      RubyOF::CPP_Callbacks.disableTransparencyBufferBlending()      
    end
    
  end
  
  
  
  
  def render_diagetic_ui(camera, lights)
    ofSetSphereResolution(32) # want higher resoultion than the default 20
    # ^ this is used to visualize the color and position of the lights
    
    using_camera camera do
      # visualize lights
      # render colored spheres to represent lights
      
      # (disable shadows for diagetic UI elements)
      @material.setCustomUniform1f(
        "u_useShadows", 0
      )
      
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
  
  
  
  # 
  # helper methods
  # 
  
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
    begin
      camera.begin
        yield # (world space rendering block)
      camera.end
    rescue Exception => e 
      camera.end
      raise e
    end
  end
  
  
  def using_framebuffer fbo # &block
    begin
      fbo.begin
        fbo.activateAllDrawBuffers() # <-- essential for using mulitple buffers
          yield fbo
      fbo.end
    rescue Exception => e 
      fbo.end
      raise e
    end
  end
  
  # void ofFbo::updateTexture(int attachmentPoint)
  
    # Explicitly resolve MSAA render buffers into textures
    # \note if using MSAA, we will have rendered into a colorbuffer, not directly into the texture call this to blit from the colorbuffer into the texture so we can use the results for rendering, or input to a shader etc.
    # \note This will get called implicitly upon getTexture();
  

end
