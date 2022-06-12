module RubyOF
  module OFX


module Alembic
  class IGeom
    
  end
  
  class Reader
    def each
      return enum_for(:each) unless block_given?
      
      self.fullnames.each do |path|
        yield self.get_node(path)
      end
    end
    
  end
  
end


end
end
