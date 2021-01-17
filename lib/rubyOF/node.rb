module RubyOF

class Node
	
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    data = {
      # :name => @name,
      :position    => self.position,
      :scale       => self.scale,
      :orientation => self.orientation
    }
    
    # TODO: encode position, orientation, scale, and anything else critical to the reconstruction of the transform (can't just encode the matrix I don't think, b/c these pieces of the transform are cached individually)
    
    # may also want to serialize "parent" ?
    # not currently using that, but will likely need it later
    # (may want to delay until later then)
    
    
    coder.represent_map to_yaml_type, data
  end
  
  def init_with(coder)
    # initialize(coder.map['mesh_name'])
    
    self.load_data(coder.map)
    
    self.generate_mesh()
  end
end

	
end
