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
        
    }
  end
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    data = {
      :name => @name,
      :ambient_color  => self.ambient_color,
      :diffuse_color  => self.diffuse_color,
      :specular_color => self.specular_color,
      :emissive_color => self.emissive_color,
      :shininess      => self.shininess
    }
    
    coder.represent_map to_yaml_type, data
  end
  
  def init_with(coder)
    initialize(coder.map['mesh_name'])
    
    self.load_data(coder.map)
    
    self.generate_mesh()
  end
end
