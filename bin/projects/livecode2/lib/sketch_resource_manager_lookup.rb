class Scene
  
end

module BasicTypes
  class ResourceManager
    def foo
      puts "hello world!"
    end
  end
end


class Inner
  def initialize
    
  end
  
  def baz
    puts load_resource
  end
end



class BasicScene < Scene
  def initialize
    
  end
  
  def run
    # main method goes here
    
    a = Inner.new
    
    require 'irb'
    binding.irb
    
  end
  
  def load_resource
    return "inner"
  end
  
  ResourceManager = BasicTypes::ResourceManager.new
end

def load_resource
  return "outer"
end



x = BasicScene.new
x.run



