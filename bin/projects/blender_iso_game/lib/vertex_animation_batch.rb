
class VertexAnimationBatch
  include RubyOF::Graphics
  
  attr_reader :interface
  
  def initialize(position_tex_path, normal_tex_path, transform_tex_path)
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
    # allows easy manipulation of entity data in transform texture
    # (uses EntityCache and EntityData, defined in C++)
    # 
    @interface = QueryInterface.new(
      @pixels[:transforms],
      PROJECT_DIR/"bin/data/geom_textures/anim_tex_cache.json"
    )
        
    entity = @interface.find_entity_by_name("CharacterTest")
    p entity
    
    
    
    # # (will handle loading from disk into the pixels in this Ruby class, rather than delegating to some other C++ object)
    
    # # load from file
    # load_transform_texture(transform_tex_path)
    # load_vertex_textures(position_tex_path, normal_tex_path)
    
    
    # # no saving to disk at this time - only Blender saves openEXR images
    # # and then we just read it here to populate the initial state
    
    
    # # copy entity data from pixels to texture
    # send_entity_data_to_gpu()
    #   @textures[:transforms].load_data(@pixels[:transforms])
    
    # # copy mesh data from pixels to texture
    # send_mesh_data_to_gpu()
    #   @textures[:positions].load_data(@pixels[:positions])
    #   @textures[:normals].load_data(@pixels[:normals])
    
    
    # # @cache.updateMaterial(material_name, material_properties)
    # # ^ this requires data from json file, so I will handle this at a higher level of abstraction
    
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
  
  
  
  
  
  
  
  
  class QueryInterface
    
    def initialize(transform_texture, json_filepath)
      # 
      # cache allows easy manipulation of transform texture from Ruby
      # 
      
      num_entities = transform_texture.height.to_i-1
      @cache = RubyOF::Project::EntityCache.new(num_entities)
      
      @cache.load(transform_texture)
      
      
      # 
      # json data stores names of entities, meshes, and materials
      # 
      
      json_string   = File.readlines(json_filepath).join("\n")
      json_data     = JSON.parse(json_string)
      
      @json = json_data
      # p @json["mesh_data_cache"]
      
    end
    
    def find_entity_by_name(target_entity_name)
      entity_idx = entity_name_to_scanline(target_entity_name)
      if entity_idx.nil?
        raise "ERROR: Could not find any entity called '#{target_entity_name}'"
      end
      # p entity_idx
      return @cache.getEntity(entity_idx)
    end
    
    
    private
    
    
    def entity_name_to_scanline(target_entity_name)
      entity_idx = nil
      
      @json["object_data_cache"].each_with_index do |data, i|
        entity_name, mesh_name, material_name = data
        
        if entity_name == target_entity_name
          # p data
          entity_idx = i
          break
        end
      end
      
      return entity_idx
    end
  end
  
  
  
  # # Does an object with this name exist in the texture?
  # # ( based on code from __object_name_to_scanline() )
  # def includes_entity?(entity_name)
    
  # end
  
  
  
  # # Does a mesh with this name exist in the texture?
  # # (more important on the ruby side, but also helpful to optimize export)
  # # 
  # # mesh_name : string
  # def includes_mesh?(mesh_name)
  #   return (mesh_name in self.mesh_data_cache)
  # end
  
  
  
  
  # def get_entity_mesh(entity_name)
  #   # + read pixel data from Image
  #   # + convert mesh_index to mesh_name using data from json file
  #   # + return mesh_name
    
  #   # return mesh_name
  # end
  
  # def get_entity_transform(entity_name)
  #   i = entity_name_to_scanline(entity_name)
  #   mat = RubyOF::CPP_Callbacks.get_entity_transform(@pixels[:transforms], i)
    
  #   return mat
  # end
  
  # def get_entity_material(entity_name)
  #   # c1    = material.rb_mat.ambient
  #   # c2    = material.rb_mat.diffuse
  #   # c3    = material.rb_mat.specular
  #   # c4    = material.rb_mat.emissive
  #   # alpha = material.rb_mat.alpha
    
  #   # return [c1, c2, c3, c4, alpha]
  # end
  

  
  # # Specify the mesh to use for a given object @ t=0 (initial condition)
  # # by setting the first pixel in the scanline to r=g=b="mesh scanline number"
  # # (3 channels have the same data; helps with visualization of the texture)
  # # This mapping will be changed by ruby code during game execution,
  # # by dynamically editing the texture in memory. However, the texture
  # # on disk will change if and only if the initial condition changes.
  # # Raise exception if no mesh with the given name has been exported yet.
  # # 
  # # entity_name  : string
  # # mesh_name : string ( mesh with this name must already exist )
  # def set_entity_mesh(entity_name, mesh_name)
  #   # 
  #   # convert mesh name data back to color data
  #   # 
  #   mesh_index = mesh_name_to_index(mesh_name)
  #   c1 = RubyOF::FloatColor.rgba([mesh_index, mesh_index, mesh_index, 1.0])
    
  #   # 
  #   # write colors on the CPU
  #   # 
  #   i = entity_name_to_scanline(entity_name)
  #   v1 = @pixels[:transforms].setColor(0, i, c1)
  # end
  
  
  # # Pack 4x4 transformation matrix for an object into 4 pixels
  # # of data in the object transform texture.
  # # 
  # # entity_name  : string
  # # transform : 4x4 transform matrix
  # def set_entity_transform(entity_name, transform)
  #   i = entity_name_to_scanline(entity_name)
    
  #   RubyOF::CPP_Callbacks.set_entity_transform(
  #     @pixels[:transforms], i, transform.to_mat4, @textures[:transforms]
  #   )
    
  #   return self
  # end
  
  
  # # Bind object to a particular material,
  # # and pack material data into 4 pixels in the object transform texture.
  # # 
  # # entity_name : string
  # # material : blender material datablock, containing RubyOF material
  # def set_entity_material(entity_name, material)
  #   # 
  #   # convert material data back to color data
  #   # 
    
  #   c1 = RubyOF::FloatColor.rgba(material.ambient.to_a + [1.0])
  #   c2 = RubyOF::FloatColor.rgba(material.diffuse.to_a + [material.alpha])
  #   c3 = RubyOF::FloatColor.rgba(material.specular.to_a + [1.0])
  #   c4 = RubyOF::FloatColor.rgba(material.emissive.to_a + [1.0])
    
  #   # 
  #   # write colors on the CPU
  #   # 
  #   i = entity_name_to_scanline(entity_name)
  #   v1 = @pixels[:transforms].setColor(5, i, c1)
  #   v2 = @pixels[:transforms].setColor(6, i, c2)
  #   v3 = @pixels[:transforms].setColor(7, i, c3)
  #   v4 = @pixels[:transforms].setColor(8, i, c4)
    
  #   # TODO: rename "transforms" texture and pixels to "entity" or "object" instead
    
  # end
  
  
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
  
  
  def update_textures
    # 
    # transfer color data to the GPU
    # 
    @textures[:transforms].load_data(@pixels[:transforms])
  end
  
  
  # 
  # serialization
  # 
  
  def save
    
  end
      
      
  def load
    
  end

  
  
  private
  
  
  def entity_name_to_scanline(entity_name)
    
  end
  
  def entity_scanline_to_name(entity_index)
    
  end
  
  def mesh_name_to_scanline(mesh_name)
    
  end
  
  def mesh_scanline_to_name(mesh_index)
    
  end
  
  
  
  # only in Ruby API
  def mesh_name_to_index(mesh_name)
    
  end
  
  # only in Ruby API
  def mesh_index_to_name(mesh_index)
    
  end
  
  
  
  # called by BlenderSync when moving mesh objects by direct manipulation
  def set_entity_transform_array(i, nested_array)
    RubyOF::CPP_Callbacks.set_entity_transform_array(
      @pixels[:transforms], i, nested_array.flatten, @textures[:transforms]
    )
    
    return self
  end
  
  
end
