
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
  
  def pack_data
    {
      'mesh_name' => self.name, # name of the data, not the object
      
      'verts'  => ['double', self.verts.size,   self.vert_filepath],
      'normals'=> ['double', self.normals.size, self.normal_filepath],
      'tris'   => self.tris
      
      # NOTE: this will mesh data from temp files, which is good enough to continue a session, but not good enough to restore progress after restarting the machine.
    }
  end
  
  def load_data(obj_data)
    self.name = obj_data['mesh_name']
    
    self.tris = obj_data['tris']
    
    obj_data['normals'].tap do |type, count, path|
      raise "ERROR: normal vector count not set for #{self.name}" if count.nil?
      raise "ERROR: path not set for #{self.name}" if path.nil?
      
      self.normal_filepath = path
      
      lines = File.readlines(path)
      
      # p lines
      # b64 -> binary -> array
      puts lines.size
      # if @last_mesh_file_n != path
        # FileUtils.rm @last_mesh_file_n unless @last_mesh_file_n.nil?
        
        # @last_mesh_file_n = path
        data = lines.last # should only be one line in this file
        self.normals = Base64.decode64(data).unpack("d#{count}")
        
        # # assuming type == double for now, but may want to support other types too
      # end
      
      @dirty = true
    end
    
    obj_data['verts'].tap do |type, count, path|
      raise "ERROR: size of vert index buffer not set for #{self.name}" if count.nil?
      raise "ERROR: path not set for #{self.name}" if path.nil?
      
      self.vert_filepath = path
      
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
        self.verts = Base64.decode64(data).unpack("d#{count}")
        
        # # assuming type == double for now, but may want to support other types too
      # end
      
      @dirty = true
    end
    
    
    if @dirty
      puts "generate mesh: #{@name}"
      self.generate_mesh()
    end
  end
  
  # 
  # YAML serialization interface
  # 
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    coder.represent_map to_yaml_type, self.pack_data
  end
  
  def init_with(coder)
    initialize()
    
    self.load_data(coder.map)
    
    self.generate_mesh()
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
    
    return @mesh.pack_data
  end
  
  # part of BlenderObject serialization interface
  def load_data(obj_data)
    # puts "loading----"
    # p obj_data
    # puts "-----------------"
    
    @mesh.load_data(obj_data)
    
    
    return self
  end
  
  
  # 
  # YAML serialization interface
  # 
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    data_hash = {
      'type' => self.class::DATA_TYPE,
      'name' =>  @name,
      
      'transform' => self.pack_transform(),
      'data' => @mesh
    }
    
    coder.represent_map to_yaml_type, data_hash
  end
  
  def init_with(coder)
    initialize()
    
    @name = coder.map['name']
    self.load_transform(coder.map['transform'])
    @mesh = coder.map['data']
  end
end
