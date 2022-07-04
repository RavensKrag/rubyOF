# tree-like data structure
# 
# assumes the structure / schema is immutable,
# although the data inside (leaf data) may change.
class World
  include RubyOF::Graphics
  
  attr_reader :data, :space, :lights
  attr_accessor :camera
  
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
    
    @storage = {} # objects that store internal state
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
      
      data = VertexAnimationTextureSet.new(@geom_texture_directory, name)
      @storage[name] = data
      @data[name] = DataInterface.new(data.cache, data.names)
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
    
    
    
    
    
  end
  
  # NOTE: mesh data (positions, normals) is separate for dynamics vs statics
    # dynamics are likely to be complex meshes (like characters) while the statics are likely to be more simplistic meshes (like tiles in a tilemap from a 2D game). With this strategy, you avoid wasting memory by packing small tiles and big characters into the same "spritesheet"
  def setup
    # static_entities
    # + load once from disk to specify initial state
    # + if reloaded, you have new initial state
    # ( still uses EntityCache to access properties, but writing values is ignored )
    
    # TODO: consider implementing read-only mode for DataInterface for static entities
    
    @storage.values.each do |texture_set|
      texture_set.setup()
    end
    
    # dynamic_entities
    # + load from disk to specify initial state
    # + if reloaded, that's a new initial state (t == 0)
    # + need other mechanism to load changes @ t != 0 (JSON message?)
    
    
    @space.update
  end
  
  
  
  def update
    @mat.load_shaders(@vert_shader_path, @frag_shader_path) do
      # on reload
      
    end
    
    @storage.values.each do |texture_set|
      texture_set.update
    end
    
    # @space.update
  end
  
  def each_texture_set #&block
    @storage.values.each do |texture_set|
      yield(texture_set.position_texture,
            texture_set.normal_texture,
            texture_set.entity_texture,
            texture_set.mesh)
    end
  end
  
  def material
    return @mat
  end
  
  def bind_history(history_obj)
    history_obj.setup(
      @storage['Characters'].entity_pixels,
      @storage['Characters'].entity_texture,
      @storage['Characters'].cache
    )
  end
  
  def draw_ui(ui_font)
    @ui_node ||= RubyOF::Node.new
    
    
    channels_per_px = 4
    bits_per_channel = 32
    bits_per_byte = 8
    bytes_per_channel = bits_per_channel / bits_per_byte
    
    
    # TODO: draw UI in a better way that does not use immediate mode rendering
    
    
    # TODO: update ui positions so that both mesh data and entity data are inspectable for both dynamic and static entities
    memory_usage = []
    entity_usage = []
    @storage.values.each_with_index do |texture_set, i|
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
      entity_usage << z
    end
    
    i = memory_usage.length
    x = memory_usage.reduce &:+
    ui_font.draw_string("  total VRAM: #{x} kb",
                        1400-200+27-50, 100+i*(189-70)+20)
    
    
    
    z = entity_usage.reduce &:+
    ui_font.draw_string("  entity texture VRAM: #{z} kb",
                        1400-200+27-50-172, 100+i*(189-70)+20+50)
    
    
    # size = @history.buffer_width * @history.buffer_height * @history.max_length
    # size = size * channels_per_px * bytes_per_channel
    # ui_font.draw_string("history memory: #{size/1000.0} kb",
    #                     120, 310)
    
    # @history
    
  end
  
  
  
  
  # NOTE: BlenderSync triggers @world.space.update when either json file or entity texture is reloaded
  
  def load_json_data(json_file_path)
    puts "load json"
    
    basename = File.basename(json_file_path)
    
    @storage.values
    .find{ |x| basename.split('.').first == x.name }
    &.tap do |texture_set|
      texture_set.load_json_data(json_file_path)
    end
  end
  
  def load_entity_texture(entity_tex_path)
    puts "reload entities"
    
    basename = File.basename(entity_tex_path)
    
    @storage.values
    .find{ |x| basename.split('.').first == x.name }
    &.tap do |texture_set|
      texture_set.load_entity_texture(entity_tex_path)
    end
  end
  
  def load_mesh_textures(position_tex_path, normal_tex_path)
    puts "load mesh data"
    # position and normals will always be updated in tandem
    # so really only need to check one path in order to
    # confirm what batch should be reloaded.
    
    basename = File.basename(position_tex_path)
    
    @storage.values
    .find{ |x| basename.split('.').first == x.name }
    &.tap do |texture_set|
      texture_set.load_mesh_textures(position_tex_path, normal_tex_path)
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
    
    # delete all lights whose names are on this list
    def gc(list_of_names)
      @lights
      .select{ |light|  list_of_names.include? light.name }
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
                        .collect{  |name|  @data['Tiles'].find_mesh_by_name(name)  }
      
      puts "=> #{out.inspect}"
      
      # TODO: return [World::Mesh] instead of [String]
      # (should work now, but needs testing)
      
      return out
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
