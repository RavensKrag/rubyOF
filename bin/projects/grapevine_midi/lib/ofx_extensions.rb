module RubyOf
  module OFX


class MidiOut
  def openPort(port_num_or_name)
    case port_num_or_name
      when Integer
        self.openPort_uint(port_num_or_name)
      when String
        self.openPort_string(port_num_or_name)
      else 
        raise ArgumentError, "Expected Integer or String but recieved #{port_num_or_name.class}"
    end
  end
end
  

end
end





module GLM


class Vec2_float
  def x
    return get_component(0)
  end
  
  def y
    return get_component(1)
  end
  
  def x=(val)
    return set_component(0, val)
  end
  
  def y=(val)
    return set_component(1, val)
  end
  
  def to_s
    format = '%.03f'
    x = format % self.x
    y = format % self.y
    z = format % self.z
    
    return "(#{x}, #{y}, #{z})"
  end
  
  def inspect
    id = '%x' % (self.object_id << 1) # get ID for object
    
    fmt = '%.03f'
    return "#<#{self.class}:0x#{id} x=#{fmt % self.x} y=#{fmt % self.y} >"
  end
  
  
  private :set_component, :get_component
end


end
