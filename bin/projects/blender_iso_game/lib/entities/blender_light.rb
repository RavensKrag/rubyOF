
class BlenderLight < BlenderObject
  DATA_TYPE = 'LIGHT' # required by BlenderObject interface
  
  extend Forwardable
  
  DEFAULT_SHADOW_MAP_SIZE = 2**10
  
  def initialize(name)
    super(name)
    
    @light = RubyOF::OFX::DynamicLight.new
    
    setPointLight()
    
    @light.setAttenuation(1.0,  0.007,   0.0002)
    # constants from learnopengl,
    # which originally got them from ogre3d's wiki
    # src: https://learnopengl.com/Lighting/Light-casters
    
    
    @size = nil
    @size_x = nil
    @size_y = nil
    
    @shadows_enabled = false
    @shadow_cam = RubyOF::OFX::ShadowCamera.new
    @shadow_map_size = DEFAULT_SHADOW_MAP_SIZE
    @shadow_cam.setSize(@shadow_map_size, @shadow_map_size)
  end
  
  WHITE = RubyOF::FloatColor.rgb([1, 1, 1])
  
  def setColor(color)
    # // Point lights emit light in all directions //
    # // set the diffuse color, color reflected from the light source //
    self.diffuse_color = color
    
    # // specular color, the highlight/shininess color //
    self.specular_color = WHITE
  end
  
  
  def setPointLight()
    @type = 'POINT'
    
    @light.setPointLight()
  end
  
  def setDirectional()
    @type = 'SUN'
    
    @light.setDirectional()
  end
  
  def setSpotlight(cutoff_degrees, exponent)
    @type = 'SPOT'
    
    # blender angle is [0, 180] (whole cone FOV)
    # while OF's angel is [0, 90] (angle from height line to edge of cone)
    # so need to divide blender's angle by 2 to convert.
    
    # puts "set spotlight: #{cutoff_degrees}"
    @spotlight_size = cutoff_degrees
    # p @spotlight_size
    
    # TODO: save degrees and exponent to instance variables so they can be dumped and then restored
    @light.setSpotlight(cutoff_degrees/2, exponent) # requires 2 args
    # float spotCutOff=45.f, float exponent=0.f
    
    # TODO: take exponent into account
    # TODO: save exponent for serialization
  end
  
  def setAreaLight(width, height)
    @type = 'AREA'
    
    @size_x = width
    @size_y = height
    
    @light.setAreaLight(@size_x, @size_y)
  end
  
  
  def_delegators :@light, :position, :orientation, :scale,
                          :position=, :orientation=, :scale=,
                          :enable, :disable, :enabled?,
                          :diffuse_color=, :specular_color=, :ambient_color=,
                          :diffuse_color,
                          :draw,
                          :setAttenuation
  
  
  attr_reader :spotlight_size
  
  
  
  
  attr_reader :shadow_cam
  
  
  def casts_shadows?
    return @shadows_enabled
  end
  
  alias :cast_shadows? :casts_shadows?
  
  # OIT_RenderPipeline#draw() -> update()
  # Core#window_resized() -> OIT_RenderPipeline#update() -> update()
  # load_data() -> enable_shadows() -> update()
  # load_data() -> disable_shadows() -> update()
  
  # NOTE: use an evented / reactive style to update when data changes, rather than a polling style that updates every frame, even when data is unchanged
  
  # TODO: make sure that the reactive style still updates parameters when code reloads
    # not currently working
    # This implies that light data is not being saved for time travel,
    # as time travel playback / rewind uses serialization.
    # Should save these properties too, as all lights are dynamic.
  
  
  def enable_shadows
    @shadows_enabled = true
  end
  
  def disable_shadows
    @shadows_enabled = false
  end
  
  # resizing shadow camera causes reallocation of FBO,
  # so only resize when the desired size changes
  def shadow_map_size=(size)
    if casts_shadows? && size != @shadow_map_size
      @shadow_map_size = size
      @shadow_cam.setSize(@shadow_map_size, @shadow_map_size)
    end
  end
  
  def shadow_map_size
    return @shadow_map_size
  end
  
  
  # update shadow camera properties
  def update
    @shadow_cam.position = @light.position
    @shadow_cam.orientation = @light.orientation
  end
  
  def setShadowUniforms(material)
    # puts "set shadow uniforms"
    material.setCustomUniform1f(
      "u_useShadows", 1
    )
    
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
  
  
  
  # 
  # YAML serialization interface
  # 
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    coder.represent_map to_yaml_type, self.data_dump
  end
  
  def init_with(coder)
    initialize(coder.map['name'])
    
    self.load_transform(coder.map['transform'])
    self.load_data(coder.map)
  end
  
  
  
  # inherits BlenderObject#data_dump
  
  # inherits BlenderObject#pack_transform()
  # inherits BlenderObject#load_transform(transform)
  
  # part of BlenderObject serialization interface
  def data_dump()
    color = self.diffuse_color # => RubyOF::FloatColor
            .to_a.first(3) # discard alpha component
    
    super().merge({
      '.data.type' => @type,
      
      'color' => ['rgb'] + color,
      
      # attentuation is not currently sent from blender in a meaningful way
      'attenuation' => [
          'rgb'
      ],
      
      # spot light properties
      'size' => ['degrees', @spotlight_size],
      
      # area light properties
      'size_x' => ['float', @size_x],
      'size_y' => ['float', @size_y],
      
      # shadow properties
      'use_shadow'         => self.casts_shadows?,
      'shadow_clip_start'  => @shadow_cam.near_clip,
      'shadow_clip_end'    => @shadow_cam.far_clip,
      'shadow_buffer_bias' => @shadow_cam.bias,
      'shadow_map_size'    => @shadow_map_size, # not from blender
      'shadow_ortho_scale' => @shadow_cam.ortho_scale, # not from blender
      'shadow_intensity'   => @shadow_cam.intensity # not from blender
    })
  end
  
  # part of BlenderObject serialization interface
  def load_data(obj_data)
    # TODO: set shadow map size from blender UI
    # TODO: set shadow intensity from blender UI
    # TODO: set ortho scale from blender UI
    
    # TODO: store shadow data on C++ object. do not duplicate values in instance variables. 
    load_light_data(obj_data)
    load_shadow_data(obj_data)
  end
  
  private
  
  def load_light_data(obj_data)
    case obj_data['.data.type']
    when 'POINT'
      # point light
      self.setPointLight() # => @type
    when 'SUN'
      # directional light
      self.setDirectional() # => @type
      
      # (orientation is on the opposite side of the sphere, relative to what blender expects)
      
    when 'SPOT'
      # spotlight
      angle = obj_data['size'][1]
      angle_deg = angle_in_degrees(angle, units: obj_data['size'][0])
      self.setSpotlight(angle_deg, 2) # => @type
      # float spotCutOff=45.f, float exponent=0.f
    when 'AREA'
      p obj_data
      width  = obj_data['size_x'][1]
      height = obj_data['size_y'][1]
      self.setAreaLight(width, height) # => @type
    end
    
    # color in blender is float, and float color is also required by OpenGL
    RubyOF::FloatColor.rgba(obj_data['color'][1..3] + [1]).tap do |color|
      self.setColor(color)
    end
  end
  
  # configure shadows
  def load_shadow_data(obj_data)
    if obj_data['use_shadow']
      # 
      # enable shadows
      # 
      @shadows_enabled = true
      self.shadow_map_size = 2**12
      
      # 
      # configure shadow camera
      # 
      
      # set general shadow buffer properties
      @shadow_cam.setRange( obj_data['shadow_clip_start'],
                            obj_data['shadow_clip_end'] )
      # @shadow_cam.bias = 0.001
      @shadow_cam.bias = obj_data['shadow_buffer_bias']
      @shadow_cam.intensity = 0.6
      
      # 
      # specify shadow properties based on light type
      # 
      case @type
      when 'POINT'
        @shadows_enabled = false
        # no shadows for now - need cubemaps to implement correctly
      
      when 'SPOT' # use perspective shadow camera
        @shadow_cam.disableOrtho()
        
        # angle of the spot light cone is the FOV of the shadow camera
        @shadow_cam.fov = @spotlight_size
        
      when 'SUN', 'AREA' # use orthographic shadow camera
        @shadow_cam.enableOrtho()
        @shadow_cam.ortho_scale = 40
      end
    else
      # 
      # disable shadows
      # 
      @shadows_enabled = false
    end
  end
  
  
  
  
  
  def angle_in_degrees(angle, units:nil)
    case units
    when 'radians'
      angle / (2*Math::PI) * 360 # rad -> degrees
    when 'degrees'
      # (already in degrees)
      angle
    else
      raise "ERROR: Unexpected unit for spotlight size detected."
    end
  end
  
end
