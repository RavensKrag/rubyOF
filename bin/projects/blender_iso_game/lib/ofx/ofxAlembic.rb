module RubyOF
  module OFX


module Alembic
  class IGeom
    def inspect
      id = '%x' % (self.object_id << 1) # get ID for object
      
      return "#<#{self.class}:0x#{id} type=#{self.type_name} full_name='#{self.full_name}'>"
    end
    
    def to_s
      "#{self.type_name} '#{self.full_name}'"
    end
    
    
    private :get_mat4
    private :get_mesh
    private :get_faceset
    
    # C++ interface is polymorphic and does not produce execeptions.
    # We will copy the polymorphic part of the interface, but trying to transfer data into the wrong data type in Ruby will result in catastrophic failure - an exception will be thrown.
    def get(obj)
      case obj
      when GLM::Mat4 # IGeom Xform -> Mat4
        if self.type_name != 'Xform'
          raise "ERROR: IGeom type must be Xform to transfer data to Mat4"
        else
          get_mat4(obj)
        end
      when RubyOF::Mesh  # IGeom PolyMesh -> ofMesh
        if self.type_name != 'PolyMesh'
          raise "ERROR: IGeom type must be PolyMesh to transfer data to ofMesh"
        else
          get_mesh(obj)
        end
      when RubyOF::OFX::Alembic::FaceSet # IGeom FaceSet -> FaceSet
        if self.type_name != 'FaceSet'
          raise "ERROR: IGeom type must be FaceSet to transfer data to FaceSet"
        else
          get_faceset(obj)
        end
      else
        raise "ERROR: Input object was of unexpected type. Do not know how to transfer data from #{self.type_name} to #{obj.class}"
      end
      
      return self
    end
    
    
    private :each_child_cpp
    
    def each_child(&block) # &block
      return enum_for(:each_child) unless block_given?
      
      inner_block = Proc.new do |child|
        block.call child
      end
      
      each_child_cpp inner_block
    end
    
  end
  
  
  
  class Reader
    include Enumerable
    
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
