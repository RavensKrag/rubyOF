
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
  
