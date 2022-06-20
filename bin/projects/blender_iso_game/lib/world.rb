# tree-like data structure
# 
# assumes the structure / schema is immutable,
# although the data inside (leaf data) may change.
class World
  include RubyOF::Graphics
  
  attr_reader :data, :space, :lights, :camera, :history
  
  MAX_NUM_FRAMES = 500
  
  def initialize(geom_texture_directory)
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
    
    
    
    # TODO: one more RubyOF::FloatPixels for the ghosts
    # TODO: one more RubyOF::Texture to render the ghosts
    
    # (can I use the array of :position images to roll back time?)
    
    puts "-----"
    # puts Dir.glob("#{PROJECT_DIR}/")
    # p (geom_texture_directory).children.map{|x| x.basename}
    
    @storage = [] # objects that store internal state
    @data = {}    # objects that form external API for accessing data
    
    # 
    # @data : Hash of DataInterface
    # query objects by name
    # to retrieve Mesh or Entity objects
    # (the wrapper objects, not the raw cache or pixel data)
    # 
    
    @geom_texture_directory = geom_texture_directory
    @geom_texture_directory.children
    .select{ |file| file.basename.to_s.end_with? ".cache.json" }
    .each do |file|
      p file
      
      name, _, _ = file.basename.to_s.split('.')
      
      @storage << VertexAnimationTextureSet.new(@geom_texture_directory, name)
      @data[name] = DataInterface.new(@storage.last.cache, @storage.last.names)
    end
    
    # TODO: should allow re-scanning of this directory when the World dynamically reloads during runtime. That way, you can start up the engine with a blank canvas, but dynamicallly add things to blender and have them appear in the game, without having to restart the game.
    
    puts "\n"*5
    
    
    @data.freeze
    
    # when you create new data, write cache -> history @ current_frame
    # when you are time traveling, change the current_frame and load -> cache
    
    # NOTE: notice that number of dynamic entities can be different than the number of static entities
    
    
    
    
    
    
    # 
    # @space : Space
    # spatial query
    # 
    @space = Space.new(@data)
    # TODO: regenerate space when project reloads
    # TODO: after refactor above, give space access to both data of static and dynamic entities
    
    
    
    # # @cache.updateMaterial(material_name, material_properties)
    # # ^ this requires data from json file, so I will handle this at a higher level of abstraction
    
    
    
    
    
    # TODO: re-connect history
    
    # @history = History.new(
    #   @storage[:dynamic].history,
    #   @storage[:dynamic][:entity_data][:pixels],
    #   @storage[:dynamic][:entity_data][:texture],
    #   @storage[:dynamic].cache
    # )
    
    
    @history = History.new(
      nil, nil, nil, nil
    )
    
  end
  
  # NOTE: mesh data (positions, normals) is separate for dynamics vs statics
    # dynamics are likely to be complex meshes (like characters) while the statics are likely to be more simplistic meshes (like tiles in a tilemap from a 2D game). With this strategy, you avoid wasting memory by packing small tiles and big characters into the same "spritesheet"
  def setup
    # static_entities
    # + load once from disk to specify initial state
    # + if reloaded, you have new initial state
    # ( still uses EntityCache to access properties, but writing values is ignored )
    
    # TODO: consider implementing read-only mode for DataInterface for static entities
    
    
    @storage.each do |texture_set|
      texture_set.setup()
    end
    
    
    # # dynamic_entities
    # # + load from disk to specify initial state
    # # + if reloaded, that's a new initial state (t == 0)
    # # + need other mechanism to load changes @ t != 0 (JSON message?)
    
    # @storage[:dynamic].tap do |data|
    #   prefix = "Characters"
    #   json_file_path    = dynamic_data_path/"#{prefix}.cache.json"
    #   position_tex_path = dynamic_data_path/"#{prefix}.position.exr"
    #   normal_tex_path   = dynamic_data_path/"#{prefix}.normal.exr"
    #   entity_tex_path   = dynamic_data_path/"#{prefix}.entity.exr"
    #   @dynamic_prefix = prefix
      
    #   load_dynamic_mesh_textures position_tex_path, normal_tex_path
    #   load_dynamic_entity_texture entity_tex_path # initial state only
    #   load_dynamic_json_data json_file_path
      
    #   # initialize rest of history buffer
    #   # (allocate correct image size, but don't clear garbage)
    #   data[:entity_data][:pixels].tap do |pixels|
    #     data[:history].allocate(pixels.width, pixels.height, MAX_NUM_FRAMES)
    #   end
      
    #   # NOTE: mesh data dimensions could change on load, but BatchGeometry assumes that the number of verts / triangles in the mesh is constant
    #   vertex_count = data[:mesh_data][:pixels][:positions].width.to_i
    #   data[:geometry].generate vertex_count
      
    #   data[:cache].load data[:entity_data][:pixels]
    # end
    
  end
  
  
  
  def update
    @mat.load_shaders(@vert_shader_path, @frag_shader_path) do
      # on reload
      
    end
  end
  
  
  # draw all the instances using GPU instancing
  # (very few draw calls)
  def draw_scene_opaque_pass
    @storage.each do |texture_set|
      # set uniforms
      @mat.setCustomUniformTexture(
        "vert_pos_tex",  texture_set.position_texture, 1
      )
      
      @mat.setCustomUniformTexture(
        "vert_norm_tex", texture_set.normal_texture, 2
      )
      
      @mat.setCustomUniformTexture(
        "entity_tex", texture_set.entity_texture, 3
      )
      
      @mat.setCustomUniform1f(
        "transparent_pass", 0
      )
      
      # draw using GPU instancing
      using_material @mat do
        instance_count = texture_set.entity_texture.height.to_i
        texture_set.geometry.mesh.draw_instanced instance_count
      end
    end
  end
  
  def draw_scene_transparent_pass
    @storage.each do |texture_set|
      # set uniforms
      @mat.setCustomUniformTexture(
        "vert_pos_tex",  texture_set.position_texture, 1
      )
      
      @mat.setCustomUniformTexture(
        "vert_norm_tex", texture_set.normal_texture, 2
      )
      
      @mat.setCustomUniformTexture(
        "entity_tex", texture_set.entity_texture, 3
      )
      
      @mat.setCustomUniform1f(
        "transparent_pass", 1
      )
      
      # draw using GPU instancing
      using_material @mat do
        instance_count = texture_set.entity_texture.height.to_i
        texture_set.geometry.mesh.draw_instanced instance_count
      end
    end
  end
  
  def draw_ui(ui_font)
    @ui_node ||= RubyOF::Node.new
    
    # TODO: draw UI in a better way that does not use immediate mode rendering
    
    
    # TODO: update ui positions so that both mesh data and entity data are inspectable for both dynamic and static entities
    memory_usage = []
    @storage.each_with_index do |texture_set, i|
      layer_name = texture_set.name
      cache = texture_set.cache
      names = texture_set.names
      
      offset = i*(189-70)
      
      ui_font.draw_string("layer: #{layer_name}",
                          450, 68+offset+20)
      
      
      current_size = 
        cache.size.times.collect{ |i|
          cache.get_entity i
        }.select{ |x|
          x.active?
        }.size
      
      ui_font.draw_string("entities: #{current_size} / #{cache.size}",
                          450+50, 100+offset+20)
      
      
      
      max_meshes = names.num_meshes
      
      num_meshes = 
        max_meshes.times.collect{ |i|
          names.mesh_scanline_to_name(i)
        }.select{ |x|
          x != nil
        }.size + 1
          # Index 0 will always be an empty mesh, so add 1.
          # That way, the size measures how full the texture is.
      
      
      ui_font.draw_string("meshes: #{num_meshes} / #{max_meshes}",
                          450+50, 133+offset+20)
      
      
      
      texture_set.entity_texture.tap do |texture|
        new_height = 100 #
        y_scale = new_height / texture.height
        
        x = 910-20
        y = (68-20)+i*(189-70)+20
        
        @ui_node.scale    = GLM::Vec3.new(1.2, y_scale, 1)
        @ui_node.position = GLM::Vec3.new(x,y, 1)

        @ui_node.transformGL
        
          texture.draw_wh(0,texture.height,0,
                          texture.width, -texture.height)

        @ui_node.restoreTransformGL
      end
      
      
      texture_set.position_texture.tap do |texture|
        width = [texture.width, 400].min # cap maximum texture width
        x = 970-40
        y = (68+texture.height-20)+i*(189-70)+20
        texture.draw_wh(x,y,0, width, -texture.height)
      end
      
      
      
      channels_per_px = 4
      bits_per_channel = 32
      bits_per_byte = 8
      bytes_per_channel = bits_per_channel / bits_per_byte
      
      texture = texture_set.position_texture
      px = texture.width*texture.height
      x = px*channels_per_px*bytes_per_channel / 1000.0
      
      texture = texture_set.normal_texture
      px = texture.width*texture.height
      y = px*channels_per_px*bytes_per_channel / 1000.0
      
      texture = texture_set.entity_texture
      px = texture.width*texture.height
      z = px*channels_per_px*bytes_per_channel / 1000.0
      
      size = x+y+z
      
      ui_font.draw_string("mem: #{size} kb",
                          1400-50, 100+offset+20)
      memory_usage << size
    end
    
    i = memory_usage.length
    x = memory_usage.reduce &:+
    ui_font.draw_string("  total VRAM: #{x} kb",
                        1400-200+27-50, 100+i*(189-70)+20)
    
  end
  
  
  
  
  # NOTE: BlenderSync triggers @world.space.update when either json file or entity texture is reloaded
  
  def load_json_data(json_file_path)
    puts "load json"
    
    basename = File.basename(json_file_path)
    texture_set = @storage.find{ |x| basename.split('.').first == x.name }
    unless texture_set.nil?
      texture_set.load_json_data(json_file_path)
    end
  end
  
  def load_entity_texture(entity_tex_path)
    puts "reload entities"
    
    basename = File.basename(entity_tex_path)
    texture_set = @storage.find{ |x| basename.split('.').first == x.name }
    unless texture_set.nil?
      texture_set.load_entity_texture(entity_tex_path)
    end
  end
  
  def load_mesh_textures(position_tex_path, normal_tex_path)
    puts "load mesh data"
    # position and normals will always be updated in tandem
    # so really only need to check one path in order to
    # confirm what batch should be reloaded.
    
    basename = File.basename(position_tex_path)
    texture_set = @storage.find{ |x| basename.split('.').first == x.name }
    unless texture_set.nil?
      texture_set.load_mesh_textures(position_tex_path, normal_tex_path)
    end
  end
  
  
  
  
  
  
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
        
        :history => HistoryBuffer.new,
          # ^ list of frames over time, not just one state
          # should combine with FrameHistory#frame_index to get data on a particular frame
          # (I know this needs to save entity data, but it may not need to save mesh data. It depends on whether or not all animation frames can fit in VRAM at the same time or not.)
      })
      
    end
    
    def cache
      return @storage[:cache]
    end
    
    def names
      return @storage[:names]
    end
    
    def history
      return @storage[:history]
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
    
    def geometry
      return @storage[:geometry]
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
    
    # convert to a hash such that it can be serialized with yaml, json, etc
    def data_dump
      data_hash = {
        'lights' => @lights
      }
      return data_hash
    end
    
    # read from a hash (deserialization)
    def load(data)
      @lights = data['lights']
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
        @data['Tiles'].each
        .collect do |entity|
          [entity.mesh.name, entity.position]
        end
      
      # p @entity_list
      
      # @entity_list.each do |name, pos|
      #   puts "#{name}, #{pos}"
      # end
      
    end
    
    
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
    end
    
    def allocate(frame_width, frame_height, max_num_frames)
      @frame_width = frame_width
      @frame_height = frame_height
      
      @size = max_num_frames
      
      @buffer.allocate(@frame_width, @frame_height*@size)
      @buffer.flip_vertical
    end
    
    def size
      return @size
    end
    
    alias :length :size
    
    # set data in history buffer on a given frame
    def []=(frame_index, frame_data)
      raise "Memory not allocated. Please call #allocate first" if @size.nil?
      
      raise IndexError, "Index #{frame_index} outside of array bounds: 0..#{@size-1}" unless frame_index >= 0 && frame_index <= @size-1
      
      # TODO: update @size if auto-growing the currently allocated segment
      
      x = 0
      y = frame_index*@frame_height
      frame_data.paste_into(@buffer, x,y)
    end
    
    # copy data from buffer into another image
    def copy_frame(frame_index, out_image)
      raise "Memory not allocated. Please call #allocate first" if @size.nil?
      
      expected_size = [@frame_width, @frame_height]
      output_size = [out_image.width, out_image.height]
      raise "Output image is the wrong size. Recieved #{output_size.inspect} but expected #{expected_size.inspect}" if expected_size != output_size
      
      w = @frame_width
      h = @frame_height
      
      x = 0
      y = frame_index*@frame_height
      
      @buffer.crop_to(out_image, x,y, w,h)
      # WARNING: ofPixels#cropTo() re-allocates memory, so I probably need to implement a better way, but this should at least work for prototyping
    end
    
    # OpenFrameworks documentation
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
    def length
      @length
    end
    
    alias :size :length
    
    
    # TODO: think about how you would implement multiple timelines
    def branch(frame_index)
      new_buffer = @buffer.dup
      return History.new(new_buffer, @cache)
    end
    
    
    
    # TODO: consider storing the current frame_count here, to have a more natural interface built around #<< / #push
    # (would clean up logic around setting frame data to not be able to set arbitrary frames, but that "cleaner" version might not actually work because of time traveling)
    
    
    # sketch out new update flow
    
    # Each update with either generate new state, or just advance time.
    # If new state was generated, we need to send it to the GPU to see it.
    
    def load_state_at(frame_index)
      # if we moved in time, but didn't generate new state
        # need to load the proper state from the buffer into the cache
        # because the cache now does not match up with the buffer
        # and the buffer has now become the authoritative source of data.
      
      @buffer.copy_frame(frame_index, @pixels)
      @cache.load @pixels
      
    end
    
    def snapshot_gamestate_at(frame_index)
      
      # if we're supposed to save frame data (not time traveling)
      
      # then try to write the data
      if @cache.update @pixels
        # if data was written...
        
        # ...then send it to the GPU
        @texture.load_data @pixels
        
        # ^ for dynamic entites, need [ofFloatPixels] where each communicates with the same instance of ofTexture
        # + one ofTexture for static entites
        # + one for dynamic entites
        # + then an extra one for rendering ghosts / trails / onion skinning of dynamic entities)
      end
      
      # always save a copy in the history buffer
      # (otherwise the buffer could have garbage at that timepoint)
      @buffer[frame_index] = @pixels
      
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
