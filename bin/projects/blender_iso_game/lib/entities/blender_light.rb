
class BlenderLight < BlenderObject
  DATA_TYPE = 'LIGHT' # required by BlenderObject interface
  
  extend Forwardable
  
  def initialize(name)
    super(name)
    
    @light = RubyOF::OFX::DynamicLight.new
    
    setPointLight()
    
    @size = nil
    @size_x = nil
    @size_y = nil
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
    @size = cutoff_degrees
    # p @size
    
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
  
  
  attr_reader :size
  
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
      
      'size' => ['degrees', @size],
      'size_x' => ['float', @size_x],
      'size_y' => ['float', @size_y]
    })
    
    # NOTE: With current loading code, only properties relevant to active light type will be restored - all other properties will be lost.
  end
  
  # part of BlenderObject serialization interface
  def load_data(obj_data)
    case obj_data['.data.type']
    when 'POINT'
      # point light
      self.setPointLight()
    when 'SUN'
      # directional light
      self.setDirectional()
      
      # (orientation is on the opposite side of the sphere, relative to what blender expects)
      
    when 'SPOT'
      # spotlight
      size = obj_data['size'][1]
      p obj_data['size'][0]
      case obj_data['size'][0]
      when 'radians'
        size_deg = size / (2*Math::PI) * 360 # rad -> degrees
      when 'degrees'
        # (already in degrees)
        size_deg = size
      else
        raise "ERROR: Unexpected unit for spotlight size detected."
      end
      
      self.setSpotlight(size_deg, 2) # requires 2 args
      # float spotCutOff=45.f, float exponent=0.f
    when 'AREA'
      width  = obj_data['size_x'][1]
      height = obj_data['size_y'][1]
      self.setAreaLight(width, height)
    end
    
    
    
    # color in blender is float, and float color is also required by OpenGL
    color = RubyOF::FloatColor.rgba(obj_data['color'][1..3] + [1])
    # self.diffuse_color  = color
    # # self.diffuse_color  = RubyOF::FloatColor.hex_alpha(0xffffff, 0xff)
    # self.specular_color = RubyOF::FloatColor.hex_alpha(0xff0000, 0xff)
    
    
    white = RubyOF::FloatColor.rgb([1, 1, 1])
    
    # // Point lights emit light in all directions //
    # // set the diffuse color, color reflected from the light source //
    self.diffuse_color = color
    
    # // specular color, the highlight/shininess color //
    self.specular_color = white
    
    
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
end
