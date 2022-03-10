class World
  include RubyOF::Graphics
  
  attr_reader :data, :space, :lights, :camera
  
  def initialize(json_file_path, position_tex_path, normal_tex_path, transform_tex_path)
    @pixels = {
      :positions  => RubyOF::FloatPixels.new,
      :normals    => RubyOF::FloatPixels.new,
      :transforms => RubyOF::FloatPixels.new
    }
    
    @textures = {
      :positions  => RubyOF::Texture.new,
      :normals    => RubyOF::Texture.new,
      :transforms => RubyOF::Texture.new
    }
    
    load_transform_texture(transform_tex_path)
    load_vertex_textures(position_tex_path, normal_tex_path)
    
    # 
    # Create a mesh consiting of a line of unconnected triangles
    # the verticies in this mesh will be transformed by the textures
    # so it doesn't matter what their exact positons are.
    # 
    @mesh = RubyOF::VboMesh.new
    
    @mesh.setMode(:triangles)
    # ^ TODO: maybe change ruby interface to mode= or similar?
    
    num_verts = @textures[:positions].width.to_i
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
      
      @mesh.addVertex(GLM::Vec3.new(size*i,0,0))
      @mesh.addTexCoord(GLM::Vec2.new(a, 0))
      
      @mesh.addVertex(GLM::Vec3.new(size*i+size,0,0))
      @mesh.addTexCoord(GLM::Vec2.new(b, 0))
      
      @mesh.addVertex(GLM::Vec3.new(size*i,size,0))
      @mesh.addTexCoord(GLM::Vec2.new(c, 0))
      
    end
    
    
    # 
    # material invokes shaders
    # 
    @mat = BlenderMaterial.new "OpenEXR vertex animation mat"
    
    shader_src_dir = PROJECT_DIR/"bin/glsl"
    @vert_shader_path = shader_src_dir/"animation_texture.vert"
    # @frag_shader_path = shader_src_dir/"phong_test.frag"
    @frag_shader_path = shader_src_dir/"phong_anim_tex.frag"
    
    
    # @mat.diffuse_color = RubyOF::FloatColor.rgba([1,1,1,1])
    # @mat.specular_color = RubyOF::FloatColor.rgba([0,0,0,0])
    # @mat.emissive_color = RubyOF::FloatColor.rgba([0,0,0,0])
    # @mat.ambient_color = RubyOF::FloatColor.rgba([0.2,0.2,0.2,0])
    
    
    
    
    # 
    # cache allows easy manipulation of transform texture from Ruby
    # 
    @pixels[:transforms].tap do |transform_texture|
      num_entities = transform_texture.height.to_i
      @cache = RubyOF::Project::EntityCache.new(num_entities)
      
      @cache.load(transform_texture)
    end
    
    
    # 
    # json data stores names of entities, meshes, and materials
    # 
    
    load_json_data json_file_path
    # p @json["mesh_data_cache"]
    
    
    
    
    # 
    # allows easy manipulation of entity data in transform texture
    # (uses EntityCache and EntityData, defined in C++)
    # 
    @data = DataInterface.new(@cache, @json)
    
    # entity = @data.find_entity_by_name("CharacterTest")
    # p entity
    
    
    
    # 
    # allows for spatial queries
    # 
    @space = Space.new(@data, @json)
    # TODO: regenerate space when project reloads
    
    
    
    
    # # @cache.updateMaterial(material_name, material_properties)
    # # ^ this requires data from json file, so I will handle this at a higher level of abstraction
    
    
    
    @camera = ViewportCamera.new
    
    @lights = LightsCollection.new
    
  end
  
  
  
  def update
    was_updated = @cache.update(@pixels[:transforms])
    # TODO: ^ update this to return something I can use as an error code if something went wrong in the update
    update_textures() if was_updated
  end
  
  def update_textures
    # 
    # transfer color data to the GPU
    # 
    @textures[:transforms].load_data(@pixels[:transforms])
  end
  
  
  
  def draw_scene
    @mat.load_shaders(@vert_shader_path, @frag_shader_path) do
      # on reload
      
    end
    
    # set uniforms
    @mat.setCustomUniformTexture(
      "vert_pos_tex",  @textures[:positions], 1
    )
    
    @mat.setCustomUniformTexture(
      "vert_norm_tex", @textures[:normals], 2
    )
    
    @mat.setCustomUniformTexture(
      "object_transform_tex", @textures[:transforms], 3
    )
      # but how is the primary texture used to color the mesh in the fragment shader bound? there is some texture being set to 'tex0' but I'm unsure where in the code that is actually specified
    
    # 
    # draw all the instances using one draw call
    # number of instances is the height of the transform texture - 1
    # (one row is just a human-readable visual marker - it is not data)
    # 
    using_material @mat do
      @mesh.draw_instanced(@pixels[:transforms].height-1)
    end
  end
  
  def draw_ui
    @textures[:positions].tap do |texture| 
      texture.draw_wh(12,300,0, texture.width, -texture.height)
    end
    
    @textures[:transforms].tap do |texture| 
      @node ||= RubyOF::Node.new
      @node.scale    = GLM::Vec3.new(1.2, 1.2, 1)
      @node.position = GLM::Vec3.new(108, 320, 1)
      
      @node.transformGL
      
          texture.draw_wh(0,texture.height,0,
                          texture.width, -texture.height)
        
      @node.restoreTransformGL
    end
  end
  
  
  
  
  def load_json_data(json_filepath)
    json_string   = File.readlines(json_filepath).join("\n")
    json_data     = JSON.parse(json_string)
    
    @json = json_data
  end
  
  def load_transform_texture(transform_tex_path)
    ofLoadImage(@pixels[:transforms], transform_tex_path.to_s)
    
    # 
    # configure all sets of pixels (CPU data) and textures (GPU data)
    # 
    pixels_list = [@pixels[:transforms]]
    textures_list = [@textures[:transforms]]
    
    pixels_list.zip(textures_list).each do |pixels, texture|
      # y axis is flipped relative to Blender???
      # openframeworks uses 0,0 top left, y+ down
      # blender uses 0,0 bottom left, y+ up
      pixels.flip_vertical
      
      puts pixels.color_at(0,2)
      
      texture.disableMipmap() # resets min mag filter
      
      texture.wrap_mode(:vertical => :clamp_to_edge,
                           :horizontal => :clamp_to_edge)
      
      texture.filter_mode(:min => :nearest, :mag => :nearest)
      
      texture.load_data(pixels)
    end
    
    # reset the cache when textures reload
    unless @cache.nil?
      @cache.load(@pixels[:transforms])
    end
  end
  
  def load_vertex_textures(position_tex_path, normal_tex_path)
    ofLoadImage(@pixels[:positions],  position_tex_path.to_s)
    ofLoadImage(@pixels[:normals],    normal_tex_path.to_s)
    
    # 
    # configure all sets of pixels (CPU data) and textures (GPU data)
    # 
    pixels_list = [@pixels[:positions], @pixels[:normals]]
    textures_list = [@textures[:positions], @textures[:normals]]
    
    pixels_list.zip(textures_list).each do |pixels, texture|
      # y axis is flipped relative to Blender???
      # openframeworks uses 0,0 top left, y+ down
      # blender uses 0,0 bottom left, y+ up
      pixels.flip_vertical
      
      puts pixels.color_at(0,2)
      
      texture.disableMipmap() # resets min mag filter
      
      texture.wrap_mode(:vertical => :clamp_to_edge,
                           :horizontal => :clamp_to_edge)
      
      texture.filter_mode(:min => :nearest, :mag => :nearest)
      
      texture.load_data(pixels)
    end
  end
  
  
  
  
  
  class Entity
    extend Forwardable
    
    attr_reader :index, :name
    
    def initialize(index, name, entity_data, mesh)
      @index = index # don't typically need this, but useful to have in #inspect for debugging
      @name = name
      @entity_data = entity_data
      
      @mesh = mesh # instance of the Mesh struct below
    end
    
    def_delegators :@entity_data, 
      :copy_material,
      :ambient,
      :diffuse,
      :specular,
      :emissive,
      :alpha,
      :ambient=,
      :diffuse=,
      :specular=,
      :emissive=,
      :alpha=
    
    def_delegators :@entity_data,
      :copy_transform,
      :position,
      :orientation,
      :scale,
      :transform_matrix,
      :position=,
      :orientation=,
      :scale=,
      :transform_matrix=
    
    def mesh=(mesh)
      # if mesh.sheet != @data.sheet
      #   raise "ERROR: Can not assign mesh from a different spritesheet"
      # end
      
      @entity_data.mesh_index = mesh.index
      @mesh = mesh
    end
    
    def mesh
      return @mesh
    end
  end
  
  
  # TODO: index only can be interpreted within some spritesheet, so need some way to make sure we're on the right sheet
  class Mesh
    attr_reader :name, :index
    
    def initialize(name, index)
      @name = name
      @index = index
    end
    
    # all meshes are solid for now
    # (may need to change this later when adding water tiles, as the character can occupy the same position as a water tile)
    def solid?
      return true
    end
  end
  
  
  # class Mesh
  #   SOLID_MESHES = [
  #     'Cube.002'
  #   ]
  #   def solid?(mesh_name)
  #     return SOLID_MESHES.include? mesh_name
  #   end
  # end
  
  # # ^ is this way of defining this backwards?
  # #   should I be tagging objects with their properties instead?
  
  
  
  
  
  
  class DataInterface
    
    def initialize(cache, json)
      @cache = cache
      @json = json
    end
    
    def find_entity_by_name(target_entity_name)
      entity_idx = entity_name_to_scanline(target_entity_name)
      
      if entity_idx.nil?
        raise "ERROR: Could not find any entity called '#{target_entity_name}'"
      end
      
      # puts "#{target_entity_name} => index #{entity_idx}"
      
      
      entity_ptr = @cache.get_entity(entity_idx)
        # puts target_entity_name
        # puts "entity -> mesh_index:"
        # puts entity_ptr.mesh_index
      mesh_name = @json['mesh_data_cache'][entity_ptr.mesh_index]
      mesh_obj = Mesh.new(mesh_name, entity_ptr.mesh_index)
      
      entity_obj = Entity.new(entity_idx, target_entity_name, entity_ptr, mesh_obj)
      
      return entity_obj
    end
    
    def find_mesh_by_name(target_mesh_name)
      mesh_idx = mesh_name_to_scanline(target_mesh_name)
      
      if mesh_idx.nil?
        raise "ERROR: Could not find any mesh called '#{target_mesh_name}'"
      end
      # p mesh_idx
      
      return Mesh.new(target_mesh_name, mesh_idx)
    end
    
    def each # &block
      return enum_for(:each) unless block_given?
      
      @cache.size.times do |i|
        entity_ptr = @cache.get_entity(i)
        
        if entity_ptr.active?
          entity_name, mesh_name, material_name =  @json['object_data_cache'][i]
          
          mesh_name = @json['mesh_data_cache'][entity_ptr.mesh_index]
          mesh_obj = Mesh.new(mesh_name, entity_ptr.mesh_index)
          
          entity_obj = Entity.new(i, entity_name, entity_ptr, mesh_obj)
          
          yield entity_obj
        end
      end
    end
    
    
    private
    
    
    # @json includes a blank entry for scanline index 0
    # even though that scanline is not represented in the cache
    # so this returns 1..(size-1)
    # but @cache.get_entity expects 0..(size-2)
    def entity_name_to_scanline(target_entity_name)
      entity_idx = nil
      
      # TODO: try using #find_index instead
      @json['object_data_cache'].each_with_index do |data, i|
        entity_name, mesh_name, material_name = data
        
        if entity_name == target_entity_name
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
  
  
  class Space
    def initialize(data, json)
      @data = data
      @json = json
      
      
      @hash = Hash.new
      
      
      self.update()
      
    end
    
    def update
      @entity_list =
        @data.each
        .collect do |entity|
          [entity.mesh.name, entity.position]
        end
      
      # p @entity_list
      
      # @entity_list.each do |name, pos|
      #   puts "#{name}, #{pos}"
      # end
      
    end
    
    # what type of tile is located at the point 'pt'?
    # Returns a list of title types (mesh datablock names)
    def point_query(pt)
      puts "point query @ #{pt}"
      
      # unless @first
      #   require 'irb'
      #   binding.irb
      # end
      
      # @first ||= true
      
      out = @entity_list.select{   |name, pos|  pos == pt  }
                        .collect{  |name, pos|  name  }
                        .collect{  |name|  @data.find_mesh_by_name(name)  }
      
      puts "=> #{out.inspect}"
      
      # TODO: return [World::Mesh] instead of [String]
      # (should work now, but needs testing)
      
      return out
    end
  end
  
  
  class LightsCollection
    def initialize
      @lights = Array.new
    end
    
    # retrieve light by name. if that name does not exist, used the supplied block to generate a light, and add that light to the list of lights
    def fetch(light_name)
      existing_light = @lights.find{ |light|  light.name == light_name }
      
      if existing_light.nil?
        if block_given?
          new_light = yield light_name
          @lights << new_light
          
          return new_light
        else
          raise "ERROR: Did not declare a block for generating new lights."
        end
      else
        return existing_light
      end
    end
    
    # TODO: implement way to delete lights
    def delete(light_name)
      @lights.delete_if{|light| light.name == light_name}
    end
    
    # delete all lights whose names are not on this list
    def gc(list_of_names)
      @lights
      .reject{ |light|  list_of_names.include? light.name }
      .each do |light|
        delete light.name
      end
    end
    
    
    def each
      return enum_for(:each) unless block_given?
      
      @lights.each do |light|
        yield light
      end
    end
    
    
  end
  
  
  
  # # Update material properties for all objects that use the given material.
  # # ( must have previously bound material using set_object_material() )
  # # 
  # # material : blender material datablock, containing RubyOF material
  # def update_material(material)
    
  # end
  
  
  # # Remove object from the transform texture.
  # # No good way right now to "garbage collect" unused mesh data.
  # # For now, that data will continue to exist in the mesh data textures,
  # # and will only be cleared out on a "clean build" of all data.
  # # 
  # # obj_name : string
  # def delete_object(obj_name)
    
  # end
  
  
  
  # 
  # serialization
  # 
  
  def save
    
  end
      
      
  def load
    
  end
  
end
