
class BlenderMeshData
  extend Forwardable
  
  attr_accessor :name
  attr_accessor :vert_filepath, :normal_filepath
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
  DATA_TYPE = 'MESH' # required by BlenderObject interface
  
  extend Forwardable
  
  attr_reader :node
  attr_accessor :mesh
  attr_accessor :color
  
  # dirty flag from BlenderObject is used to signal
  # that an one instance in a batch has changed position
  
  def initialize
    @mesh = BlenderMeshData.new
    @node = RubyOF::Node.new
  end
  
  def_delegators :@node, :position, :position=,
                         :orientation, :orientation=,
                         :scale, :scale=
  
  
  # inherits BlenderObject#data_dump
  
  # inherits BlenderObject#pack_transform()
  # inherits BlenderObject#load_transform(transform)
  
  # part of BlenderObject serialization interface
  def pack_data()
    raise "ERROR: Can't pack data for #{@name} because mesh data filepaths in underlying BlenderMeshData object #{@mesh.name} were never set." if @mesh.normal_filepath.nil? or @mesh.vert_filepath.nil?
    
    # filepath variables never get set for instanced meshes, because they bypass #load_data(), and instead set @mesh directly
      # (could fix by putting all the data on BlenderMeshData instead, which kinda makes more sense anyway)
    
    
    # NOTE: 'mesh_name' not saved for some objects
    
    {
      'mesh_name' => @mesh.name, # name of the data, not the object
      
      'verts'  => ['double', @mesh.verts.size,   @mesh.vert_filepath],
      'normals'=> ['double', @mesh.normals.size, @mesh.normal_filepath],
      'tris'   => @mesh.tris
      
      # NOTE: this will mesh data from temp files, which is good enough to continue a session, but not good enough to restore progress after restarting the machine.
    }
  end
  
  # part of BlenderObject serialization interface
  def load_data(obj_data)
    # puts "loading----"
    # p obj_data
    # puts "-----------------"
    
    @mesh.name = obj_data['mesh_name']
    
    @mesh.tris = obj_data['tris']
    
    obj_data['normals'].tap do |type, count, path|
      raise "ERROR: normal vector count not set for #{@mesh.name}" if count.nil?
      raise "ERROR: path not set for #{@mesh.name}" if path.nil?
      
      @mesh.normal_filepath = path
      
      lines = File.readlines(path)
      
      # p lines
      # b64 -> binary -> array
      puts lines.size
      # if @last_mesh_file_n != path
        # FileUtils.rm @last_mesh_file_n unless @last_mesh_file_n.nil?
        
        # @last_mesh_file_n = path
        data = lines.last # should only be one line in this file
        @mesh.normals = Base64.decode64(data).unpack("d#{count}")
        
        # # assuming type == double for now, but may want to support other types too
      # end
      
      @dirty = true
    end
    
    obj_data['verts'].tap do |type, count, path|
      raise "ERROR: size of vert index buffer not set for #{@mesh.name}" if count.nil?
      raise "ERROR: path not set for #{@mesh.name}" if path.nil?
      
      @mesh.vert_filepath = path
      
      lines = File.readlines(path)
      
      # p lines
      # b64 -> binary -> array
      puts lines.size
      # if @last_mesh_file_v != path
        # FileUtils.rm @last_mesh_file_v unless @last_mesh_file_v.nil?
        
        # @last_mesh_file_v = path
        data = lines.last # should only be one line in this file
        # puts "data =>"
        # p data
        @mesh.verts = Base64.decode64(data).unpack("d#{count}")
        
        # # assuming type == double for now, but may want to support other types too
      # end
      
      @dirty = true
    end
    
    
    if @dirty
      puts "generate mesh"
      @mesh.generate_mesh()
    end
    
    
    return self
  end
end
