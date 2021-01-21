class BlenderMaterial < RubyOF::OFX::DynamicMaterial
  attr_reader :name
  
  def initialize(name)
    super()
    @name = name
  end
  
  
  # TODO: implement serialization methods
  # convert to a hash such that it can be serialized with yaml, json, etc
  def data_dump
    {
        'type' => 'MATERIAL',
        'name' => @name,
        'ambient_color'  => self.ambient_color,
        'diffuse_color'  => self.diffuse_color,
        'specular_color' => self.specular_color,
        'emissive_color' => self.emissive_color,
        'shininess'      => self.shininess
    }
  end
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    coder.represent_map to_yaml_type, self.data_dump
  end
  
  def init_with(coder)
    initialize(coder['name'])
    
    self.ambient_color  = coder['ambient_color']
    self.diffuse_color  = coder['diffuse_color']
    self.specular_color = coder['specular_color']
    self.emissive_color = coder['emissive_color']
    self.shininess      = coder['shininess']
    
  end
end
