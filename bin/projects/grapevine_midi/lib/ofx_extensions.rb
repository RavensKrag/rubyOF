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
  MidiStatusCodes = [
    :unknown,
    
    # channel voice messages
    :note_off           ,
    :note_on            ,
    :control_change     ,
    :program_change     ,
    :pitch_bend         ,
    :aftertouch         ,
    :poly_aftertouch    ,
    
    # system messages
    :sysex              ,
    :time_code          ,
    :song_pos_pointer   ,
    :song_select        ,
    :tune_request       ,
    :sysex_end          ,
    :time_clock         ,
    :start              ,
    :continue           ,
    :stop               ,
    :active_sensing     ,
    :system_reset       
  ];
  
  private :getStatus
  def status
    # C++ code accesses struct and converts enum to int
    # this Ruby code converts that int into a Symbol
    i = getStatus()
    return MidiStatusCodes[i]
  end
  
  
  # (doing equality in c++ is not that much faster)
  alias :== :cpp_equality
  private :cpp_equality
  # def ==(other)
  #   # if other.is_a? self.class
  #   #   # TODO: implement this comparison
  #   #   self.each_byte.to_a == other.each_byte.to_a
  #   # else
  #   #   return false
  #   # end
  #   cpp_equality(other)
  # end
  
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


