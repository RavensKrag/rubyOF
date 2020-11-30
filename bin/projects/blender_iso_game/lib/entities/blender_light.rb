
class BlenderLight < BlenderObject
  extend Forwardable
  
  def initialize
    @light = RubyOF::Light.new
    
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
  
  def setSpotlight(cutoff_radians, exponent)
    @type = 'SPOT'
    
    @size = cutoff_radians
    
    size_deg = cutoff_radians / (2*Math::PI) * 360
    @light.setSpotlight(size_deg, 0) # requires 2 args
    # float spotCutOff=45.f, float exponent=0.f
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
                          :diffuse_color
  
  # inherits BlenderObject#data_dump
  
  
  def pack_data()
    color = self.diffuse_color # => RubyOF::FloatColor
            .to_a.first(3) # discard alpha component
    
    {
        'light_type' => @type,
        'color' => ['rgb'] + color,
        'size' => [
          'radians', @size
        ],
        'size_x' => [
          'float', @size_x
        ],
        'size_y' => [
          'float', @size_y
        ]
    }
  end
  
  
  def load_data(obj_data)
    case obj_data['light_type']
    when 'POINT'
      # point light
      self.setPointLight()
    when 'SUN'
      # directional light
      self.setDirectional()
      
      # (orientation is on the opposite side of the sphere, relative to what blender expects)
      
    when 'SPOT'
      # spotlight
      size_rad = obj_data['size'][1]
      size_deg = size_rad / (2*Math::PI) * 360
      self.setSpotlight(size_deg, 0) # requires 2 args
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
end
