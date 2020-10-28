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



# TODO: implement #dup for all relevant RubyOF C++ wrapped types (vectors, etc)
module RubyOF
  class Color
    # clone vs dup
    # 1) a clone of a frozen object is still frozen
    #    a dup of a frozen object is not frozen
    # 
    # 2) clone copies singleton methods
    #    (implying that the metaclass is the same for two objects)
    # 
    # src: https://medium.com/@raycent/ruby-clone-vs-dup-8a49b295f29a
    
    # should copy all channels: rgba (don't forget the alpha)
    def dup
      copy = self.class.new()
      
      copy.set_hex(self.get_hex())
      copy.a = self.a
      
      return copy
    end
  end
end
  
