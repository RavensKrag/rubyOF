# TODO: create a better name for this
class VertexAnimationTextureSet
  include RubyOF::Graphics
  
  attr_reader :name
  
  def initialize(data_dir, name)
    @data_dir = data_dir
    @name = name
    # @static_prefix = name
    
    @storage = FixedSchemaTree.new({
      :mesh_data => {
        :pixels => {
          :positions  => RubyOF::FloatPixels.new,
          :normals    => RubyOF::FloatPixels.new,
        },
        
        :textures => {
          :positions  => RubyOF::Texture.new,
          :normals    => RubyOF::Texture.new,
        }
      },
      
      :entity_data => {
        :pixels  => RubyOF::FloatPixels.new,
        :texture => RubyOF::Texture.new,
      },
      
      :names => TextureJsonCache.new, # <- "json file"
        # ^ convert name to scanline AND scanline to name
      
      :geometry => BatchGeometry.new, # size == max tris per mesh in batch
      
      :cache => RubyOF::Project::EntityCache.new, # size == num dynamic entites
    })
    
  end
  
  def cache
    return @storage[:cache]
  end
  
  def names
    return @storage[:names]
  end
  
  def position_texture
    return @storage[:mesh_data][:textures][:positions]
  end
  
  def normal_texture
    return @storage[:mesh_data][:textures][:normals]
  end
  
  def entity_texture
    return @storage[:entity_data][:texture]
  end
  
  def entity_pixels
    return @storage[:entity_data][:pixels]
  end
  
  def mesh
    return @storage[:geometry].mesh
  end
  
  
  def setup
    json_file_path    = @data_dir/"#{@name}.cache.json"
    position_tex_path = @data_dir/"#{@name}.position.exr"
    normal_tex_path   = @data_dir/"#{@name}.normal.exr"
    entity_tex_path   = @data_dir/"#{@name}.entity.exr"
    
    load_mesh_textures position_tex_path, normal_tex_path
    load_entity_texture entity_tex_path
    load_json_data json_file_path
    
    
    # NOTE: mesh data dimensions could change on load, but BatchGeometry assumes that the number of verts / triangles in the mesh is constant
    vertex_count = @storage[:mesh_data][:pixels][:positions].width.to_i
    @storage[:geometry].generate vertex_count
    
    @storage[:cache].load @storage[:entity_data][:pixels]
  end
  
  
  def load_json_data(json_file_path)
    @storage[:names].load json_file_path
    
    # @storage[:static][:cache].load @storage[:static][:entity_data][:pixels]
  end
  
  def load_entity_texture(entity_tex_path)
    # 
    # configure all sets of pixels (CPU data) and textures (GPU data)
    # 
    
    [
      [ entity_tex_path,
        @storage[:entity_data][:pixels],
        @storage[:entity_data][:texture] ],
    ].each do |path_to_file, pixels, texture|
      ofLoadImage(pixels, path_to_file.to_s)
      
      # y axis is flipped relative to Blender???
      # openframeworks uses 0,0 top left, y+ down
      # blender uses 0,0 bottom left, y+ up
      pixels.flip_vertical
      
      # puts pixels.color_at(0,2)
      
      texture.disableMipmap() # resets min mag filter
      
      texture.wrap_mode(:vertical   => :clamp_to_edge,
                        :horizontal => :clamp_to_edge)
      
      texture.filter_mode(:min => :nearest, :mag => :nearest)
      
      texture.load_data(pixels)
    end
    
    # reset the cache when textures reload
    @storage[:cache].load @storage[:entity_data][:pixels]
  end
  
  def load_mesh_textures(position_tex_path, normal_tex_path)
    # 
    # configure all sets of pixels (CPU data) and textures (GPU data)
    # 
    
    [
      [ position_tex_path,
        @storage[:mesh_data][:pixels][:positions],
        @storage[:mesh_data][:textures][:positions] ],
      [ normal_tex_path,
        @storage[:mesh_data][:pixels][:normals],
        @storage[:mesh_data][:textures][:normals] ]
    ].each do |path_to_file, pixels, texture|
      ofLoadImage(pixels, path_to_file.to_s)
      
      # y axis is flipped relative to Blender???
      # openframeworks uses 0,0 top left, y+ down
      # blender uses 0,0 bottom left, y+ up
      pixels.flip_vertical
      
      # puts pixels.color_at(0,2)
      
      texture.disableMipmap() # resets min mag filter
      
      texture.wrap_mode(:vertical   => :clamp_to_edge,
                        :horizontal => :clamp_to_edge)
      
      texture.filter_mode(:min => :nearest, :mag => :nearest)
      
      texture.load_data(pixels)
    end
  end
  
end



# ASSUME: @pixels and @texture are the same dimensions, as they correspond to CPU and GPU representations of the same data


# ASSUME: @pixels and @texture are the same dimensions, as they correspond to CPU and GPU representations of the same data
# ASSUME: @pixels[:positions] and @pixels[:normals] have the same dimensions



class TextureJsonCache
  def initialize
    @json = nil
  end
  
  def load(json_filepath)
    unless File.exist? json_filepath
      raise "No file found at '#{json_filepath}'. Expected JSON file with names of meshes and entities. Try re-exporting from Blender."
    end
    
    json_string   = File.readlines(json_filepath).join("\n")
    json_data     = JSON.parse(json_string)
    
    @json = json_data
  end
  
  
  def num_meshes
    return @json["mesh_data_cache"].size
  end
  
  
  
  def entity_scanline_to_name(i)
    data = @json['entity_data_cache'][i]
    return data['entity name']
  end
  
  def mesh_scanline_to_name(i)
    return @json['mesh_data_cache'][i]
  end
  
  
  
  def entity_name_to_scanline(target_entity_name)
    entity_idx = nil
    
    # TODO: try using #find_index instead
    @json['entity_data_cache'].each_with_index do |data, i|
      if data['entity name'] == target_entity_name
        # p data
        entity_idx = i
        break
      end
    end
    
    return entity_idx
  end
  
  # @json includes a blank entry for scanline index 0
  # even though that scanline is not represented in the cache
  def mesh_name_to_scanline(target_mesh_name)
    mesh_idx = nil
    
    # TODO: try using #find_index instead
    @json['mesh_data_cache'].each_with_index do |mesh_name, i|
      if mesh_name == target_mesh_name
        # p data
        mesh_idx = i
        break
      end
    end
    
    return mesh_idx
  end
  
end






class BatchGeometry
  attr_reader :mesh
  
  def initialize
    @mesh = nil
  end
  
  def generate(vertex_count)
    @mesh = create_mesh(vertex_count)
  end
  
  private
  
  def create_mesh(num_verts)
    # 
    # Create a mesh consiting of a line of unconnected triangles
    # the verticies in this mesh will be transformed by the textures
    # so it doesn't matter what their exact positons are.
    # 
    RubyOF::VboMesh.new.tap do |mesh|
      mesh.setMode(:triangles)
      # ^ TODO: maybe change ruby interface to mode= or similar?
      
      num_tris = num_verts / 3
      
      size = 1 # useful when prototyping to increase this for visualization
      num_tris.times do |i|
        a = i*3+0
        b = i*3+1
        c = i*3+2
        # DEBUG PRINT: show indicies assigned to tris an verts
        # p [i, [a,b,c]]
        
        
        # UV coordinates specified in pixel indicies
        # will offset by half a pixel in the shader
        # to sample at the center of each pixel
        
        mesh.addVertex(GLM::Vec3.new(size*i,0,0))
        mesh.addTexCoord(GLM::Vec2.new(a, 0))
        
        mesh.addVertex(GLM::Vec3.new(size*i+size,0,0))
        mesh.addTexCoord(GLM::Vec2.new(b, 0))
        
        mesh.addVertex(GLM::Vec3.new(size*i,size,0))
        mesh.addTexCoord(GLM::Vec2.new(c, 0))
        
      end
    end
    
  end
end




