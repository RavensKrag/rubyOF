module RubyOF
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

class MidiMessage
  def ==(other)
    if other.is_a? self.class
      # TODO: implement this comparison
      self.each_byte.to_a == other.each_byte.to_a
    else
      return false
    end
  end
  
  private :get_num_bytes, :get_byte
  
  def each_byte() # &block
    return enum_for(:each_byte) unless block_given?
    
    get_num_bytes.times do |i|
      yield get_byte(i)
    end
    
  end
  
  def [](i)
    return get_byte(i)
  end
  
  
  def to_s
    return "[#{self.each_byte.to_a.map{|x| "0x#{'%02x' % x}" }.join(", ")}]"
  end
  
  def inspect
    id = '%x' % (self.object_id << 1) # get ID for object
    
    fmt = '%.03f'
    return "#<#{self.class}:0x#{id} bytes=#{self.to_s} >"
  end
end
  

end
end

# @cpp_ptr["midiMessageQueue"].map{ |x| x.each_byte.to_a }
# # ^ this is the interface we want
# #   Can't create a full array at the C++ level - obj lifetime is too confusing
# #   Instead, implement an interface to get one byte at a time,
# #   and then at the ruby level, we can create an Enumeration -> Array



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
