
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
  
  
  def data_dump
    orientation = self.orientation
    position = self.position
    scale = self.scale
    
    color = self.diffuse_color.to_a
            .first(3) # discard alpha component
            .map{|x| x / 255.0 } # convert to float from 0..1
    
    {
        'type' => 'LIGHT',
        'name' =>  @name,
        'light_type' => @type,
        'rotation' => [
          'Quat',
          orientation.w, orientation.x, orientation.y, orientation.z
        ],
        'position' => [
          'Vec3',
          position.x, position.y, position.z
        ],
        'scale' => [
          'Vec3',
          scale.x, scale.y, scale.z
        ],
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
end
