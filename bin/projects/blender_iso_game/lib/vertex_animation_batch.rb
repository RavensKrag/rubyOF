
class VertexAnimationBatch
  include RubyOF::Graphics
  
  attr_reader :transform_data
  
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
    # query interface
    # 
    
    @transform_data = TransformData.new(@pixels[:transforms])
    
    
    
    
    
    
    
    
    # C++ structures
    @entity_cache = EntityCache.new(size)
    |-> [ EntityData, EntityData, EntityData ]
    # (a pool of Entities, in an easy to edit format)
    
    
    EntityData
    |-> [(bool)active, (bool)changed, (int)mesh_index, Node, MaterialProperties]
    # (active is true if and only if this block of data is being used - it's basically an object pool in terms of memory management)
    # (set changed=true on ofNode edit event, or MaterialPropreties edit event)
    
    
    MaterialProperties
    |-> [ (float)ambient,
          (float)diffuse,
          (float)specular,
          (float)emissive,
          (float)alpha ]
    
    # (will handle loading from disk into the pixels in this Ruby class, rather than delegating to some other C++ object)
    
    # load from file
    load_transform_texture(transform_tex_path)
    load_vertex_textures(position_tex_path, normal_tex_path)
    
    
    # no saving to disk at this time - only Blender saves openEXR images
    # and then we just read it here to populate the initial state
    
    
    
    # (only manipulate entity data, not mesh data)
    # (mat4x4 needed for entity will update automatically as position, orientation, and scale are updated)
    @entity_cache.load(@pixels[:transforms])   # read from pixel data into cache
    @entity_cache.update(@pixels[:transforms]) # write changed data to pixels
    @entity_cache.flush(@pixels[:transforms])  # write ALL data to pixels
    
    
    # copy entity data from pixels to texture
    send_entity_data_to_gpu()
      @textures[:transforms].load_data(@pixels[:transforms])
    
    # copy mesh data from pixels to texture
    send_mesh_data_to_gpu()
      @textures[:positions].load_data(@pixels[:positions])
      @textures[:normals].load_data(@pixels[:normals])
    
    
    
    # read from the cache
    # (should fail if EntityCache#load has not yet been called)
    @entity_cache.getEntityMesh(entity_index) # => mesh_index
    @entity_cache.getEntityTransform(entity_index) # => ofNode
    @entity_cache.getEntityMaterial(entity_index) # => MaterialProperties
    
    
    # write into the cache
    # (later can transfer cache to pixels)
    @entity_cache.setEntityMesh(entity_index, mesh_index)
    @entity_cache.setEntityTransform(entity_index, node)
    @entity_cache.setEntityMaterial(entity_index, material_properties)
    @entity_cache.deleteEntity(entity_index)
    
    
    # @cache.updateMaterial(material_name, material_properties)
    # ^ this requires data from json file, so I will handle this at a higher level of abstraction
    
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
  
  
  
  
  # def includes_entity?(entity_name)
  # def includes_mesh?(mesh_name)
  # def get_entity_mesh(entity_name)
  # def get_entity_transform(entity_name)
  # def get_entity_material(entity_name)
  # def set_entity_mesh(entity_name, mesh_name)
  # def set_entity_transform(entity_name, transform)
  # def set_entity_material(entity_name, material)
  # def update_material(material)
  # def delete_entity(entity_name)
  
  
  
  # Does an object with this name exist in the texture?
  # ( based on code from __object_name_to_scanline() )
  def includes_entity?(entity_name)
    
  end
  
  
  
  # Does a mesh with this name exist in the texture?
  # (more important on the ruby side, but also helpful to optimize export)
  # 
  # mesh_name : string
  def includes_mesh?(mesh_name)
    return (mesh_name in self.mesh_data_cache)
  end
  
  
  
  
  def get_entity_mesh(entity_name)
    # + read pixel data from Image
    # + convert mesh_index to mesh_name using data from json file
    # + return mesh_name
    
    # return mesh_name
  end
  
  def get_entity_transform(entity_name)
    i = entity_name_to_scanline(entity_name)
    mat = RubyOF::CPP_Callbacks.get_entity_transform(@pixels[:transforms], i)
    
    return mat
  end
  
  def get_entity_material(entity_name)
    # c1    = material.rb_mat.ambient
    # c2    = material.rb_mat.diffuse
    # c3    = material.rb_mat.specular
    # c4    = material.rb_mat.emissive
    # alpha = material.rb_mat.alpha
    
    # return [c1, c2, c3, c4, alpha]
  end
  

  
  # Specify the mesh to use for a given object @ t=0 (initial condition)
  # by setting the first pixel in the scanline to r=g=b="mesh scanline number"
  # (3 channels have the same data; helps with visualization of the texture)
  # This mapping will be changed by ruby code during game execution,
  # by dynamically editing the texture in memory. However, the texture
  # on disk will change if and only if the initial condition changes.
  # Raise exception if no mesh with the given name has been exported yet.
  # 
  # entity_name  : string
  # mesh_name : string ( mesh with this name must already exist )
  def set_entity_mesh(entity_name, mesh_name)
    # 
    # convert mesh name data back to color data
    # 
    mesh_index = mesh_name_to_index(mesh_name)
    c1 = RubyOF::FloatColor.rgba([mesh_index, mesh_index, mesh_index, 1.0])
    
    # 
    # write colors on the CPU
    # 
    i = entity_name_to_scanline(entity_name)
    v1 = @pixels[:transforms].setColor(0, i, c1)
  end
  
  
  # Pack 4x4 transformation matrix for an object into 4 pixels
  # of data in the object transform texture.
  # 
  # entity_name  : string
  # transform : 4x4 transform matrix
  def set_entity_transform(entity_name, transform)
    i = entity_name_to_scanline(entity_name)
    
    RubyOF::CPP_Callbacks.set_entity_transform(
      @pixels[:transforms], i, transform.to_mat4, @textures[:transforms]
    )
    
    return self
  end
  
  
  # Bind object to a particular material,
  # and pack material data into 4 pixels in the object transform texture.
  # 
  # entity_name : string
  # material : blender material datablock, containing RubyOF material
  def set_entity_material(entity_name, material)
    # 
    # convert material data back to color data
    # 
    
    c1 = RubyOF::FloatColor.rgba(material.ambient.to_a + [1.0])
    c2 = RubyOF::FloatColor.rgba(material.diffuse.to_a + [material.alpha])
    c3 = RubyOF::FloatColor.rgba(material.specular.to_a + [1.0])
    c4 = RubyOF::FloatColor.rgba(material.emissive.to_a + [1.0])
    
    # 
    # write colors on the CPU
    # 
    i = entity_name_to_scanline(entity_name)
    v1 = @pixels[:transforms].setColor(5, i, c1)
    v2 = @pixels[:transforms].setColor(6, i, c2)
    v3 = @pixels[:transforms].setColor(7, i, c3)
    v4 = @pixels[:transforms].setColor(8, i, c4)
    
    # TODO: rename "transforms" texture and pixels to "entity" or "object" instead
    
  end
  
  
  # Update material properties for all objects that use the given material.
  # ( must have previously bound material using set_object_material() )
  # 
  # material : blender material datablock, containing RubyOF material
  def update_material(material)
    
  end
  
  
  # Remove object from the transform texture.
  # No good way right now to "garbage collect" unused mesh data.
  # For now, that data will continue to exist in the mesh data textures,
  # and will only be cleared out on a "clean build" of all data.
  # 
  # obj_name : string
  def delete_object(obj_name)
    
  end
  
  
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
  
  
  
  
  def get_entity_transform(i)
    # # pull colors out of image on CPU side
    # # similar to how the shader pulls data out on the GPU side
    
    # v1 = @pixels[:transforms].color_at(1, i)
    # v2 = @pixels[:transforms].color_at(2, i)
    # v3 = @pixels[:transforms].color_at(3, i)
    # v4 = @pixels[:transforms].color_at(4, i)
    
    # mat = GLM::Mat4.new(GLM::Vec4.new(v1.r, v2.r, v3.r, v4.r),
    #                     GLM::Vec4.new(v1.g, v2.g, v3.g, v4.g),
    #                     GLM::Vec4.new(v1.b, v2.b, v3.b, v4.b),
    #                     GLM::Vec4.new(v1.a, v2.a, v3.a, v4.a));
    
    mat = RubyOF::CPP_Callbacks.get_entity_transform(@pixels[:transforms], i)
    
    return mat
  end
  
  def set_entity_transform(i, mat)
    # # 
    # # convert mat4 transform data back to color data
    # # 
    # mv0 = mat[0]
    # mv1 = mat[1]
    # mv2 = mat[2]
    # mv3 = mat[3]
    
    # # v1.r = mat[0][0]
    # # v1.g = mat[1][0]
    # # v1.b = mat[2][0]
    # # v1.a = mat[3][0]
    
    # c1 = RubyOF::FloatColor.rgba([mv0[0], mv1[0], mv2[0], mv3[0]])
    # c2 = RubyOF::FloatColor.rgba([mv0[1], mv1[1], mv2[1], mv3[1]])
    # c3 = RubyOF::FloatColor.rgba([mv0[2], mv1[2], mv2[2], mv3[2]])
    # c4 = RubyOF::FloatColor.rgba([mv0[3], mv1[3], mv2[3], mv3[3]])
    
    
    # # 
    # # write colors on the CPU
    # # 
    # v1 = @pixels[:transforms].setColor(1, i, c1)
    # v2 = @pixels[:transforms].setColor(2, i, c2)
    # v3 = @pixels[:transforms].setColor(3, i, c3)
    # v4 = @pixels[:transforms].setColor(4, i, c4)
    
    # # 
    # # transfer color data to the GPU
    # # 
    # @textures[:transforms].load_data(@pixels[:transforms])
    
    RubyOF::CPP_Callbacks.set_entity_transform(
      @pixels[:transforms], i, mat, @textures[:transforms]
    )
    
    return self
  end
  
  def mutate_entity_transform(i) # &block
    transform = self.get_entity_transform(i)
    
      transform = yield transform
    
    self.set_entity_transform(i, transform)
  end
  
  # called by BlenderSync when moving mesh objects by direct manipulation
  def set_entity_transform_array(i, nested_array)
    RubyOF::CPP_Callbacks.set_entity_transform_array(
      @pixels[:transforms], i, nested_array.flatten, @textures[:transforms]
    )
    
    return self
  end
  
  
  class TransformData
    FIELDS = [:mesh_id, :position, :rotation, :scale, :ambient, :diffuse, :specular, :emmissive]
    
    def initialize(pixels)
      @pixels = pixels
    end
    
    # what fields can you ask for in #query?
    def fields
      return FIELDS
    end
    
    # run a query (like a database) and pull out the desired fields.
    # returns an Array, where each entry has the values of the desired fields.
    # 
    # ex) self.transform_data.query(:mesh_id, :position)
    #     => [ [id_0, pos_0], [id_1, pos_1], [id_2, pos_2], ..., [id_n, pos_n] ]
    def query(*query_fields)
      # # convert symbols to integers
      # query_i = query_fields.collect{|field|  FIELD_TO_INDEX[field] }
      
      # # error checking
      # if query_i.any?{|x| x.nil? }
      #   raise "Unknown field specified in query."
      # end
      
      
      # p query_fields
      
      # run actual query at C++ level
      table = RubyOF::CPP_Callbacks.query_transform_pixels(@pixels)
      
      table.collect do |data|
        map = FIELDS.zip(data).to_h
        
        query_fields.collect{ |field|  map[field] }
      end
      
    end
    
    
  end
  
end
