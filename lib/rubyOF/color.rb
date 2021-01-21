module RubyOF

class Color
  CHANNEL_MAX = 255
  
  include Freezable
  
  def to_s
    "<Color (rgba): #{self.r}, #{self.g}, #{self.b}, #{self.a}>"
  end
  
  def ==(other)
    return false if self.class != other.class
    
    [:r, :g, :b, :a].all? do |channel|
      self.send(channel) == other.send(channel)
    end
  end
  
  def to_a
    return [self.r,self.g,self.b,self.a]
  end
  
  def rgba=(color_array)
    raise ArgumentError, "Expected an array of size 4 that encodes rgba color data (each channel should be an integer, with a maximum of #{CHANNEL_MAX} per channel)" unless color_array.size == 4
    
    self.r,self.g,self.b,self.a = color_array
  end
  
  class << self
    def rgba(color_array)
      color = self.new
      color.rgba = color_array
      
      return color
    end
    
    def rgb(color_array)
      raise ArgumentError, "Expected an array of size 3 that encodes rgb color data (each channel should be an integer, with a maximum of #{CHANNEL_MAX} per channel)" unless color_array.size == 3
      
      # Must add, can't push because arrays in Ruby are objects
      # and all objects in Ruby are reference types.
      # Thus, the array provided will always be an in/out parameter.
      self.rgba(color_array + [CHANNEL_MAX])
    end
    
    def hex(hex)
      color = self.new
      color.set_hex(hex, CHANNEL_MAX)
      return color
    end
    
    def hex_alpha(hex, alpha)
      color = self.new
      color.set_hex(hex, alpha)
      return color
    end
  end
  
  # 
  # YAML serialization interface
  # 
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    coder['rgba'] = self.to_a
  end
  
  def init_with(coder)
    initialize()
    
    self.rgba = coder['rgba']
  end
end

class FloatColor
  CHANNEL_MAX = 1
  
  include Freezable
  
  def to_s
    "<FloatColor (rgba): #{self.r}, #{self.g}, #{self.b}, #{self.a}>"
  end
  
  def ==(other)
    return false if self.class != other.class
    
    [:r, :g, :b, :a].all? do |channel|
      self.send(channel) == other.send(channel)
    end
  end
  
  def to_a
    return [self.r,self.g,self.b,self.a]
  end
  
  def rgba=(color_array)
    raise ArgumentError, "Expected an array of size 4 that encodes rgba color data (each channel should be an float, in the range 0 to 1)" unless color_array.size == 4
    
    self.r,self.g,self.b,self.a = color_array
  end
  
  class << self
    def rgba(color_array)
      color = self.new
      color.rgba = color_array
      
      return color
    end
    
    def rgb(color_array)
      raise ArgumentError, "Expected an array of size 3 that encodes rgb color data (each channel should be an float, in the range 0 to 1)" unless color_array.size == 3
      
      # Must add, can't push because arrays in Ruby are objects
      # and all objects in Ruby are reference types.
      # Thus, the array provided will always be an in/out parameter.
      self.rgba(color_array + [CHANNEL_MAX])
    end
    
    def hex(hex)
      color = self.new
      color.set_hex(hex, CHANNEL_MAX)
      return color
    end
    
    def hex_alpha(hex, alpha)
      color = self.new
      color.set_hex(hex, alpha)
      return color
    end
  end
  
  # 
  # YAML serialization interface
  # 
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    coder['rgba'] = self.to_a
  end
  
  def init_with(coder)
    initialize()
    
    self.rgba = coder['rgba']
  end
end

class ShortColor
  CHANNEL_MAX = 65535
  
  
  include Freezable
  
  def to_s
    "<ShortColor (rgba): #{self.r}, #{self.g}, #{self.b}, #{self.a}>"
  end
  
  def ==(other)
    return false if self.class != other.class
    
    [:r, :g, :b, :a].all? do |channel|
      self.send(channel) == other.send(channel)
    end
  end
  
  
  def to_a
    return [self.r,self.g,self.b,self.a]
  end
  
  def rgba=(color_array)
    raise ArgumentError, "Expected an array of size 4 that encodes rgba color data (each channel should be an float, in the range 0 to 1)" unless color_array.size == 4
    
    self.r,self.g,self.b,self.a = color_array
  end
  
  class << self
    def rgba(color_array)
      color = self.new
      color.rgba = color_array
      
      return color
    end
    
    def rgb(color_array)
      raise ArgumentError, "Expected an array of size 3 that encodes rgb color data (each channel should be an float, in the range 0 to 1)" unless color_array.size == 3
      
      # Must add, can't push because arrays in Ruby are objects
      # and all objects in Ruby are reference types.
      # Thus, the array provided will always be an in/out parameter.
      self.rgba(color_array + [CHANNEL_MAX])
    end
    
    def hex(hex)
      color = self.new
      color.set_hex(hex, CHANNEL_MAX)
      return color
    end
    
    def hex_alpha(hex, alpha)
      color = self.new
      color.set_hex(hex, alpha)
      return color
    end
  end
  
  # 
  # YAML serialization interface
  # 
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    coder['rgba'] = self.to_a
  end
  
  def init_with(coder)
    initialize()
    
    self.rgba = coder['rgba']
  end
end




end
