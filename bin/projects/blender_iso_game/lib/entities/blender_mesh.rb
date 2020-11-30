
class BlenderMeshData
  extend Forwardable
  
  attr_accessor :verts, :normals, :tris
  def_delegators :@mesh, :draw, :draw_instanced
  
  def initialize
    @mesh = RubyOF::VboMesh.new
  end
  
  def generate_mesh
    return unless !@verts.nil? and !@normals.nil? and !@tris.nil?
    
    
    # p mesh.methods
    @mesh.setMode(:triangles)
    
    
    t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # @normals.each_cons(3) do |vert|
    #   @mesh.addNormal(GLM::Vec3.new(*vert))
    # end
    
    # @tris.each do |vert_idxs|
    #   vert_coords = vert_idxs.map{|i|  @verts[i]  }
      
    #   vert_coords.each do |x,y,z|
    #     @mesh.addVertex(GLM::Vec3.new(x,y,z))
    #   end
    # end
    
    # p @mesh
    # p @normals
    RubyOF::CPP_Callbacks.generate_mesh(@mesh, @normals,
                                               @verts,
                                               @tris.flatten)
    
    t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    dt = t1-t0;
    puts "time - mesh generation: #{dt}"
    
  end
end

class BlenderMesh < BlenderObject
  extend Forwardable
  
  attr_reader :node
  attr_accessor :mesh
  attr_accessor :color
  
  def initialize
    @mesh = BlenderMeshData.new
    @node = RubyOF::Node.new
  end
  
  def_delegators :@node, :position, :position=,
                         :orientation, :orientation=,
                         :scale, :scale=
  
  
  # convert to a hash such that it can be serialized with yaml, json, etc
  def data_dump
    orientation = self.orientation
    position = self.position
    scale = self.scale
    
    {
        'type' => 'MESH',
        'name' =>  @name,
        
        'transform' => {
          'rotation' => [
            'Quat',
            orientation.w, orientation.x, orientation.y, orientation.z
          ],
          'position' => [
            'Vec3',
            position.x, position.y, position.z
          ],
          'scale' => [
            'Vec3',
            scale.x, scale.y, scale.z
          ]
        },
        
        # 'data' => {
        #   'verts': [
        #     'double', num_verts, tmp_vert_file_path
        #   ],
        #   'normals': [
        #     'double', num_normals, tmp_normal_file_path
        #   ],
        #   'tris' : index_buffer
        # }
    }
  end
end
