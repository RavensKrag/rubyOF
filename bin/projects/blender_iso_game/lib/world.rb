# tree-like data structure
# 
# assumes the structure / schema is immutable,
# although the data inside (leaf data) may change.
class World
  include RubyOF::Graphics
  
  attr_reader :data, :space, :lights, :camera, :history
  
  MAX_NUM_FRAMES = 500
  
  def initialize
    # material invokes shaders
    @mat = BlenderMaterial.new "OpenEXR vertex animation mat"
    
    shader_src_dir = PROJECT_DIR/"bin/glsl"
    @vert_shader_path = shader_src_dir/"animation_texture.vert"
    # @frag_shader_path = shader_src_dir/"phong_test.frag"
    @frag_shader_path = shader_src_dir/"phong_anim_tex.frag"
    
    # @mat.diffuse_color = RubyOF::FloatColor.rgba([1,1,1,1])
    # @mat.specular_color = RubyOF::FloatColor.rgba([0,0,0,0])
    # @mat.emissive_color = RubyOF::FloatColor.rgba([0,0,0,0])
    # @mat.ambient_color = RubyOF::FloatColor.rgba([0.2,0.2,0.2,0])
    
    
    
    @camera = ViewportCamera.new
    
    @lights = LightsCollection.new
    
    # TODO: serialize lights and load on startup
    # TODO: serialize camera and load on startup
    
    
    
    
    # TODO: one more RubyOF::FloatPixels for the ghosts
    # TODO: custom C++ function to blit the data from many frames into one big frame
    # TODO: one for RubyOF::Texture to render the ghosts
    
    # (can I use the array of :position images to roll back time?)
    
    
    
    
    # TODO: change EntityCache so the size isn't specified until you bind a Pixels object using EntityCache#load
    
    
    
    # @t = frame_index # currently tracked in FrameHistory
    @storage = FixedSchemaTree.new({
      
      :static => {
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
        
        :geometry => BatchGeometry.new, # size == num static entities
        
        :cache => RubyOF::Project::EntityCache.new # size == num static entities
      },
      
      
      :dynamic => {
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
        
        :history => HistoryBuffer.new,
          # ^ list of frames over time, not just one state
          # should combine with FrameHistory#frame_index to get data on a particular frame
        
        :names => TextureJsonCache.new, # <- "json file"
          # ^ convert name to scanline AND scanline to name
        
        :geometry => BatchGeometry.new, # size == num dynamic entities
        
        :cache => RubyOF::Project::EntityCache.new # size == num dynamic entites
      }
    })
    
    # when you create new data, write cache -> history @ current_frame
    # when you are time traveling, change the current_frame and load -> cache
    
    # NOTE: notice that number of dynamic entities can be different than the number of static entities
    
    
    # 
    # @data : Hash of DataInterface
    # query objects by name
    # to retrieve Mesh or Entity objects
    # (the wrapper objects, not the raw cache or pixel data)
    # 
    @data = {
      :static => DataInterface.new(
        @storage[:static][:cache], @storage[:static][:names]
      ),
      
      :dynamic => DataInterface.new(
        @storage[:dynamic][:cache], @storage[:dynamic][:names]
      )
    }.freeze
    
    
    # 
    # @space : Space
    # spatial query
    # 
    @space = Space.new(@data)
    # TODO: regenerate space when project reloads
    # TODO: after refactor above, give space access to both data of static and dynamic entities
    
    
    
    # # @cache.updateMaterial(material_name, material_properties)
    # # ^ this requires data from json file, so I will handle this at a higher level of abstraction
    
    
    @history = History.new(
      @storage[:dynamic][:history],
      @storage[:dynamic][:entity_data][:pixels],
      @storage[:dynamic][:entity_data][:texture],
      @storage[:dynamic][:cache]
    )
    
  end
  
  
  
  def setup(json_file_path, position_tex_path, normal_tex_path, entity_tex_path)
    @storage[:static].tap do |data|
      # data[:mesh_data].load position_tex_path, normal_tex_path
      # data[:entity_data].load entity_tex_path
      # data[:names].load json_file_path
      
      load_static_mesh_textures position_tex_path, normal_tex_path
      load_static_entity_texture entity_tex_path
      load_static_json_data json_file_path
      
      
      # NOTE: mesh data dimensions could change on load, but BatchGeometry assumes that the number of verts / triangles in the mesh is constant
      vertex_count = data[:mesh_data][:pixels][:positions].width.to_i
      data[:geometry].generate vertex_count
      
      data[:cache].load data[:entity_data][:pixels]
    end
    
    @storage[:dynamic].tap do |data|
      # data[:mesh_data].load position_tex_path, normal_tex_path
      # # data[:entity_data].load entity_tex_path
      # data[:history].each do |entity_data|
      #   entity_data.load entity_tex_path
      # end
      # data[:names].load json_file_path
      
      
      load_dynamic_mesh_textures position_tex_path, normal_tex_path
      load_dynamic_entity_texture entity_tex_path # initial state only
      load_dynamic_json_data json_file_path
      
      # initialize rest of history buffer
      # (allocate correct image size, but don't clear garbage)
      data[:entity_data][:pixels].tap do |pixels|
        data[:history].allocate(pixels.width, pixels.height, MAX_NUM_FRAMES)
      end
      
      # NOTE: mesh data dimensions could change on load, but BatchGeometry assumes that the number of verts / triangles in the mesh is constant
      vertex_count = data[:mesh_data][:pixels][:positions].width.to_i
      data[:geometry].generate vertex_count
      
      data[:cache].load data[:entity_data][:pixels]
    end
    
    
    
    
    # @static_entities  = RubyOF::FloatPixels.new
    #   # + load once from disk to specify initial state
    #   # + if reloaded, you have new initial state
    # @dynamic_entities = RubyOF::FloatPixels.new
    #   # + load from disk to specify initial state
    #   # + if reloaded, that's a new initial state (t == 0)
    #   # + need other mechanism to load changes @ t != 0 (JSON message?)
    
    
    
    
    
    # how do I deal with the cache when splitting dynamic / static?
    # need to be able to read transform components (positon, orientation, scale)
    # from the static entities, but don't need to set them.
    # on the contrary, if you set them, it might be problematic.
    # should I still use the same EntityCache ?
    
    
    # NOTE: mesh data (positions, normals) should be separate for dynamics vs statics
      # dynamics are likely to be complex meshes (like characters) while the statics are likely to be more simplistic meshes (like tiles in a tilemap from a 2D game). With this strategy, you avoid wasting memory by packing small tiles and big characters into the same "spritesheet"
      
    
  end
  
  
  
  def update
    @mat.load_shaders(@vert_shader_path, @frag_shader_path) do
      # on reload
      
    end
  end
  
  
  # draw all the instances using GPU instancing
  # (very few draw calls)
  def draw_scene
    [
      [
        @storage[:static][:mesh_data],
        @storage[:static][:entity_data][:texture],
        @storage[:static][:geometry]
      ],
      [
        @storage[:dynamic][:mesh_data],
        @storage[:dynamic][:entity_data][:texture],
        @storage[:dynamic][:geometry]
      ]
    ].each do |mesh_data, entity_texture, geometry|
      # set uniforms
      @mat.setCustomUniformTexture(
        "vert_pos_tex",  mesh_data[:textures][:positions], 1
      )
      
      @mat.setCustomUniformTexture(
        "vert_norm_tex", mesh_data[:textures][:normals], 2
      )
      
      @mat.setCustomUniformTexture(
        "entity_tex", entity_texture, 3
      )
      
      # draw using GPU instancing
      using_material @mat do
        instance_count = entity_texture.height.to_i
        geometry.mesh.draw_instanced instance_count
      end
    end
    
  end
  
  def draw_ui
    @ui_node ||= RubyOF::Node.new
    
    # TODO: draw UI in a better way that does not use immediate mode rendering
    
    
    # TODO: update ui positions so that both mesh data and entity data are inspectable for both dynamic and static entities
    
    
    @storage[:static][:mesh_data][:textures][:positions].tap do |texture| 
      texture.draw_wh(12,300,0, texture.width, -texture.height)
    end
    
    @storage[:static][:entity_data][:texture].tap do |texture| 
      @ui_node.scale    = GLM::Vec3.new(1.2, 1.2, 1)
      @ui_node.position = GLM::Vec3.new(108, 320, 1)
      
      @ui_node.transformGL
      
          texture.draw_wh(0,texture.height,0,
                          texture.width, -texture.height)
        
      @ui_node.restoreTransformGL
    end
    
    
    
    @storage[:dynamic][:mesh_data][:textures][:positions].tap do |texture| 
      texture.draw_wh(12,300,0, texture.width, -texture.height)
    end
    
    @storage[:dynamic][:entity_data][:texture].tap do |texture| 
      @ui_node.scale    = GLM::Vec3.new(1.2, 1.2, 1)
      @ui_node.position = GLM::Vec3.new(108+50, 320, 1)
      
      @ui_node.transformGL
      
          texture.draw_wh(0,texture.height,0,
                          texture.width, -texture.height)
        
      @ui_node.restoreTransformGL
    end
    
    
  end
  
  
  
  
  # NOTE: BlenderSync triggers @world.space.update when either json file or entity texture is reloaded
  
  def load_json_data(json_file_path)
    
  end
  
  def load_entity_texture(entity_tex_path)
    
  end
  
  def load_mesh_textures(position_tex_path, normal_tex_path)
    
  end
  
  
  
  
  
  
  
  
  def load_static_json_data(json_file_path)
    @storage[:static][:names].load json_file_path
  end
  
  def load_static_entity_texture(entity_tex_path)
    # 
    # configure all sets of pixels (CPU data) and textures (GPU data)
    # 
    
    [
      [ entity_tex_path,
        @storage[:static][:entity_data][:pixels],
        @storage[:static][:entity_data][:texture] ],
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
    @storage[:static][:cache].load @storage[:static][:entity_data][:pixels]
  end
  
  def load_static_mesh_textures(position_tex_path, normal_tex_path)
    # 
    # configure all sets of pixels (CPU data) and textures (GPU data)
    # 
    
    [
      [ position_tex_path,
        @storage[:static][:mesh_data][:pixels][:positions],
        @storage[:static][:mesh_data][:textures][:positions] ],
      [ normal_tex_path,
        @storage[:static][:mesh_data][:pixels][:normals],
        @storage[:static][:mesh_data][:textures][:normals] ]
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
  
  
  
  
  
  def load_dynamic_json_data(json_file_path)
    @storage[:dynamic][:names].load json_file_path
  end
  
  # dynamic entities can change their position over time,
  # so the data stored on disk represents the initial state.
  def load_dynamic_entity_texture(entity_tex_path)
    # 
    # configure all sets of pixels (CPU data) and textures (GPU data)
    # 
    
    [
      [ entity_tex_path,
        @storage[:dynamic][:entity_data][:pixels],
        @storage[:dynamic][:entity_data][:texture] ],
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
    
    # # reset the cache when textures reload
    # pixels = @storage[:dynamic][:entity_data][:buffer][0]
    # @storage[:dynamic][:cache].load pixels
    
    # TODO: figure out how to refresh history when initial state changed during execution
  end
  
  # mesh data doesn't change over time, so dynamic case is the same as static,
  # just setting the data in different parts of @storage
  def load_dynamic_mesh_textures(position_tex_path, normal_tex_path)
    # 
    # configure all sets of pixels (CPU data) and textures (GPU data)
    # 
    
    [
      [ position_tex_path,
        @storage[:dynamic][:mesh_data][:pixels][:positions],
        @storage[:dynamic][:mesh_data][:textures][:positions] ],
      [ normal_tex_path,
        @storage[:dynamic][:mesh_data][:pixels][:normals],
        @storage[:dynamic][:mesh_data][:textures][:normals] ]
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
    
    
    
    def entity_scanline_to_name(i)
      entity_name, mesh_name, material_name = @json['entity_data_cache'][i]
      return entity_name
    end
    
    def mesh_scanline_to_name(i)
      return @json['mesh_data_cache'][i]
    end
    
    
    
    def entity_name_to_scanline(target_entity_name)
      entity_idx = nil
      
      # TODO: try using #find_index instead
      @json['entity_data_cache'].each_with_index do |data, i|
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
  
  
  # access Entity / Mmesh data by name
  class DataInterface
    def initialize(cache, names)
      @cache = cache
      @names = names
    end
    
    
    def find_entity_by_name(target_entity_name)
      entity_idx = @names.entity_name_to_scanline(target_entity_name)
      
      if entity_idx.nil?
        raise "ERROR: Could not find any entity called '#{target_entity_name}'"
      end
      
      # puts "#{target_entity_name} => index #{entity_idx}"
      
      
      entity_ptr = @cache.get_entity(entity_idx)
        # puts target_entity_name
        # puts "entity -> mesh_index:"
        # puts entity_ptr.mesh_index
      mesh_name = @names.mesh_scanline_to_name(entity_ptr.mesh_index)
      mesh_obj = Mesh.new(mesh_name, entity_ptr.mesh_index)
      
      entity_obj = Entity.new(entity_idx, target_entity_name, entity_ptr, mesh_obj)
      
      return entity_obj
    end
    
    def find_mesh_by_name(target_mesh_name)
      mesh_idx = @names.mesh_name_to_scanline(target_mesh_name)
      
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
          entity_name = @names.entity_scanline_to_name(i)
          
          mesh_name = @names.mesh_scanline_to_name(entity_ptr.mesh_index)
          mesh_obj = Mesh.new(mesh_name, entity_ptr.mesh_index)
          
          entity_obj = Entity.new(i, entity_name, entity_ptr, mesh_obj)
          
          yield entity_obj
        end
      end
    end
    
    
  end
  
  
  # enable spatial queries
  class Space
    def initialize(data)
      @data = data
      
      
      @hash = Hash.new
      
      
      self.update()
      
    end
    
    # TODO: update this to use @static_entities and @dynamic_entities, rather than outdated @data
    def update
      @entity_list =
        @data[:static].each
        .collect do |entity|
          [entity.mesh.name, entity.position]
        end
      
      # p @entity_list
      
      # @entity_list.each do |name, pos|
      #   puts "#{name}, #{pos}"
      # end
      
    end
    
    
    
    
    # TODO: update this to use @static_entities and @dynamic_entities, rather than outdated @data
    
    # TODO: consider separate api for querying static entities (tiles) vs dynamic entities (gameobjects)
      # ^ "tile" and "gameobject" nomenclature is not used throughout codebase.
      #   may want to just say "dynamic" and "static" instead
    
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
  
  
  
  
  
  
  
  
  # store the data needed for history
  class HistoryBuffer
    def initialize
      @buffer = RubyOF::FloatPixels.new
      
      @frame_width = nil
      @frame_height = nil
      
      @size = nil
      @max_size = nil
    end
    
    def allocate(frame_width, frame_height, max_num_frames)
      @frame_width = frame_width
      @frame_height = frame_height
      
      @size = 0
      @max_size = max_num_frames
      
      @buffer.allocate(@frame_width, @frame_height*@max_size)
      @buffer.flip_vertical
    end
    
    def size
      return @size
    end
    
    alias :length :size
    
    # TODO: consider storing the current frame_count in this buffer, so that the buffer can have a more natural interface built around #<< / #push
    # (would clean up logic around setting frame data to not be able to set arbitrary frames, but that "cleaner" version might not actually work because of time traveling)
    
    # set data in history buffer on a given frame
    def []=(frame_index, frame_data)
      # TODO: raise exception if you try to write to an index beyond what is supported by @max_size
      # TODO: update @size if auto-growing the currently allocated segment
      
      x = 0
      y = frame_index*@frame_height
      frame_data.paste_into(@buffer, x,y)
    end
    
    # copy data from buffer into another image
    def crop_to(out_image, frame_index)
      w = @frame_width
      h = @frame_height
      
      x = 0
      y = frame_index*@frame_height
      
      @buffer[frame_index].crop_to(out_image, x,y, w,h)
      # WARNING: ofPixels#cropTo() re-allocates memory, so I probably need to implement a better way, but this should at least work for prototyping
    end
    
    # @history = [RubyOF::FloatPixels]
    # -> most recent one is blitted onto @pixels[:entities][:dynamic]
    
      # use ofPixels::pasteInto(ofPixels &dst, size_t x, size_t y)
      # 
      # "Paste the ofPixels object into another ofPixels object at the specified index, copying data from the ofPixels that the method is being called on to the ofPixels object at &dst. If the data being copied doesn't fit into the destination then the image is cropped."
      
    
      # cropTo(...)
      # void ofPixels::cropTo(ofPixels &toPix, size_t x, size_t y, size_t width, size_t height)

      # This crops the pixels into the ofPixels reference passed in by toPix. at the x and y and with the new width and height. As a word of caution this reallocates memory and can be a bit expensive if done a lot.

    
  end
  
  
  # external API to access history data via @world.history
  # control writing / loading data on dynamic entities over time
  class History
    # TODO: use named arguments, because the positions are extremely arbitrary
    def initialize(history_buffer, pixels, texture, cache)
      @buffer = history_buffer
        # @buffer : HistoryBuffer object
        # storage is one big image,
        # but API is like an array of images
      
      @pixels = pixels
      @texture = texture
      @cache = cache
      
      
      # @texture : RubyOF::Texture
      @length = 0
    end
    
    
    # TODO: properly implement length (needed by FrameHistory - may need to refactor that class instead)
    # (true implementation should live in HistoryBuffer, not this class)
    def length
      @length
    end
    
    alias :size :length
    
    
    # TODO: think about how you would implement multiple timelines
    def branch(frame_index)
      new_buffer = @buffer.dup
      return History.new(new_buffer, @cache)
    end
    
    
    
    
    
    # sketch out new update flow
    
    # Each update with either generate new state, or just advance time.
    # If new state was generated, we need to send it to the GPU to see it.
    
    def load_state_at(frame_index)
      # if we moved in time, but didn't generate new state
        # need to load the proper state from the buffer into the cache
        # because the cache now does not match up with the buffer
        # and the buffer has now become the authoritative source of data.
      
      @buffer.crop_to(@pixels, frame_index)
      @cache.load @pixels
      
    end
    
    def snapshot_gamestate_at(frame_index)
      
      # if we're supposed to save frame data (not time traveling)
      
      if @cache.needs_update? # ...and there's data to write
        # then write the data
        @cache.update @pixels
        
        # and send it to the GPU
        @texture.load_data @pixels
        
        # and make a copy for the history buffer
        @buffer[frame_index] = @pixels
        
        
        # ^ for dynamic entites, need [ofFloatPixels] where each communicates with the same instance of ofTexture
        # + one ofTexture for static entites
        # + one for dynamic entites
        # + then an extra one for rendering ghosts / trails / onion skinning of dynamic entities)
      end
      
      
    end
    
  end
  
  
  
  # # Update material properties for all objects that use the given material.
  # # ( must have previously bound material using set_object_material() )
  # # 
  # # material : blender material datablock, containing RubyOF material
  # def update_material(material)
    
  # end
  
  
  # # Remove object from the entity texture.
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
