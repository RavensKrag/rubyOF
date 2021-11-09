
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
    
    load_textures(position_tex_path, normal_tex_path, transform_tex_path)
    
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
  
  
  def load_textures(position_tex_path, normal_tex_path, transform_tex_path)
    ofLoadImage(@pixels[:positions],  position_tex_path.to_s)
    ofLoadImage(@pixels[:normals],    normal_tex_path.to_s)
    ofLoadImage(@pixels[:transforms], transform_tex_path.to_s)
    
    # 
    # configure all sets of pixels (CPU data) and textures (GPU data)
    # 
    @pixels.values.zip(@textures.values).each do |pixels, texture|
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
