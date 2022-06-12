
# DEPRECIATED
# This class should no longer be used.
# Only keeping this around to reference YAML serialization interface.
# 
# Use EntityData system instead.
# See world.rb for details.
class BlenderMesh < BlenderObject
  # 
  # YAML serialization interface
  # 
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    data_hash = {
      'type' => self.class::DATA_TYPE,
      'name' =>  @name,
      
      'mesh_data' => @mesh,
      'material' => @material,
      'transform' => encode_transform_to_base64()
    }
    
    coder.represent_map to_yaml_type, data_hash
  end
  
  def init_with(coder)
    initialize(coder['name'], coder['mesh_data'], coder['material'])
    
    load_transform_from_base64(coder['transform'])
    
    # p transform
    
    
  end
  
end
