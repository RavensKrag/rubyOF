module GLM

class Vec2
  include RubyOF::Freezable
  
  def to_a
    return [self.x, self.y]
  end
  
  def to_s
    format = '%.03f'
    x = format % self.x
    y = format % self.y
        
    return "(#{x}, #{y})"
  end
  
  def inspect
    super()
  end
  
  
  
  # hide C++ level helper methods
  private :get_component
  private :set_component
  
  
  # get / set value of a component by numerical index
  def [](i)
    return get_component(i)
  end
  
  def []=(i, value)
    return set_component(i, value.to_f)
  end
  
  
  # get / set values of component by axis name
  %w[x y].each_with_index do |component, i|
    # getters
    # (same as array-style interface)
    define_method component do
      get_component(i)
    end 
    
    # setters
    # (use special C++ function to make sure data is written back to C++ land)
    define_method "#{component}=" do |value|
      set_component(i, value.to_f)
    end 
  end
  
  
  def to_cpvec2
    return CP::Vec2.new(self.x, self.y)
  end
  
  # 
  # YAML serialization interface
  # 
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    coder['xy'] = self.to_a
  end
  
  def init_with(coder)
    x,y = coder['xy']
    
    initialize(x,y)
  end
end


end
