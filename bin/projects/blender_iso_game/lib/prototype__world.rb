



# Space                     spatial queries
# VertexAnimationBatch      combine textures with shaders to render scene
# DataCache                 named queries / update data in the textures



class World
  def initialize(geometry_texture_dir)
    # rendering interface
    # + generate generic mesh that is parameterized by textures
    # + loads image data from disk to memory
    # + transports Image from main memory to Texture in VRAM
    # + manages dynamic reloading of shaders via BlenderMaterial
    # + initiates rendering using GPU instancing
    # 
    # + get entity transform
    # + set entity transform
    @batch = VertexAnimationBatch.new(
      geometry_texture_dir/"animation.position.exr",
      geometry_texture_dir/"animation.normal.exr",
      geometry_texture_dir/"animation.transform.exr"
    )
    
    
    # named query interface
    # + object name -> object data (transform, mesh, material)
    # + mesh name -> mesh data
    # 
    # + new interface to mutate object data (transform, mesh, material)
    @data = DataCache.new(@batch, geometry_texture_dir/"anim_tex_cache.json")
    
    
    # spatial query interface
    @space = Space.new(@batch, @data)
    # ^ needs access to the object texture to access the transform data
    # ^ needs access to DataCache to resolve mesh id -> possible objects
  end
  
  def draw_scene()
    @batch.draw_scene()
  end
end


@world = World.new


@world.draw_scene()

@world.space.point_query( x )


v = GLM::Vec3.new(1, 0, 0)

character = @world.data.find_object_by_name("CharacterTest")
character.transform.to_mat4
character.transform.position += v


@world.data.update_textures





class DataCache
  def initialize(batch, json_filepath)
    @batch = batch
    @json_filepath = json_filepath
    
    
    @entities = []
    # ^ only create this sort of ORM object for entities that need to be modified. should be able to go at least a little faster if we don't have to check over things that will never cause changes to the texture
  end
  
  # update filepath, reload the file, and refresh the data in the table
  def update_json_filepath(json_filepath)
    @json_filepath = json_filepath
    
    # TODO: reload the file
    # TODO: refresh the data in the table
  end
  
  
  # object name => scanline
  # material => object name       can't resolve - many objects can use one mesh
  # mesh name => object name      can't resolve - many objects can use one mesh
  
  # object name => mesh name
  # object name => material
  
  
  # spatial query should resolve: position => object name
  # how do you get the mesh name given the position?
  
    # object_name = Space#point_query(position) 
    # mesh_name = QueryTable#foo(object_name)
      # object_name -> mesh_name
  
  
  # position => object name 
  
  
  
  
  # need entity name to id (to get transforms out of the texture)
  
  # can query VertexAnimationBatch and get mesh ids out
  # currently using mesh id -> name to convert those ids to names
  
    # if that query interface allowed for getting the scanline ids
    # then I could use the new JSON data to compute the object names
    # not just the mesh names
    # 
    # this would allow me to distinguish between
    # different objects that use the same mesh
  
  
  
  def find_object(obj_name_or_id)
    if obj_name_or_id.is_a? Numeric
      find_object_by_id(obj_name_or_id)
      
    elsif obj_name_or_id.is_a? String
      find_object_by_name(obj_name_or_id)
      
    elsif obj_name_or_id.is_a? Symbol
      raise "Please use Strings for object name lookup, rather than symbols (for cross-language serialization reasons). "
      
    else
      raise "Unknown object identifier type specified. Please use either a number (scanline index) or a String (object name)"
      
    end
  end
  
  
  def find_object_by_id(obj_id)
    # interpret the id as a scanline index
    
    object_data_row = @object_cache[obj_id]
    
    return GameObjectData.new(obj_id, *object_data_row)
  end
  
  def find_object_by_name(obj_name)
    # search row-by-row until you find the name
    
    object_data_row, obj_id =  
      @object_cache
      .each_with_index
      .find do |data, i|
        cached_object_name, cached_mesh_name, cached_material_name = data
        
        obj_name == cached_object_name
      end
    
    return GameObjectData.new(obj_id, *object_data_row)
  end
  
  # mesh name -> mesh ID     (not very useful - can only get name back out)
  # mesh ID -> mesh name     needed to resolve some spatial queries
  
  def mesh_id_to_name(mesh_id)
    return @mesh_cache[mesh_id].clone
  end
  
  
  
  # def find_mesh(mesh_name)
  #   mesh_name =  
  #     @mesh_cache.find do |cached_mesh_name|
  #       cached_mesh_name == mesh_name
  #     end
    
  #   return MeshData.new(mesh_name)
  # end
  
  
  # Specify the mesh to use for a given object, 
  def set_object_mesh(obj_name, mesh_name)
    data = self.find_object_by_name(obj_name)
    data.mesh_name = mesh_name
    
    @batch.transform_data
  end
  
  
  
  
  def update_textures
    # update transforms if transform changed
    transform_batch = @entities.select{ |entity|  entity.transform.dirty? }
    transform_batch.each do |entity|  
      self.set_object_transform(entity.name, entity.transform.to_mat4) 
    end
    
    # update meshes if mesh changed (e.g. new animation frame)
    mesh_batch = @entities.select{ |entity| entity.mesh.dirty? }
    mesh_batch.each do |entity|
      self.set_object_mesh(entity.name, entity.mesh.name)
    end
    
    # update material property blocks if material changed
    material_batch = @entities.select{ |entity| entity.material.dirty? }
    material_batch.each do |entity|
      # mesh_id = @world.batch.mesh_name_to_id(entity.mesh.name)
      # @world.batch.set_entity_mesh(entity.index, mesh_id)
      
      self.set_object_material(entity.name, entity.material)
    end
    
    # push data to GPU if anything has changed
    if [transform_batch, mesh_batch, material_batch].any?{|x| not x.empty? }
      @textures[:transforms].load_data(@pixels[:transforms])
      # ^ this data currently lives in VertexAnimationBatch, which suggests that all of this code should really move into there (but maybe not, because this code seems to interact with the ORM interface layer, not the core table-like / database-like interface)
    end

  end
  
  def set_object_transform(entity_name, mat4) 
    entity_id = entity_name_to_id(entity_name)
    
  end
  
  def set_object_mesh(entity_name, mesh_name)
    entity_id = entity_name_to_id(entity_name)
    mesh_id = @batch.mesh_name_to_id(entity.mesh.name)
    @batch.set_entity_mesh(entity_id, mesh_id)
  end
  
  def set_object_material(entity_name, material)
    
  end
  
  
  
  
  
  
  private
  
  
  
  # what happens if you try to set data on this object?
  # do you want to use this like an ORM and save the data back some how?
  # if you save it back, then what happens to like... the Blender data???
  
  # why would you want to set this data?
    # changing mesh to advance an animation 
    # need to change the cache, and change the texture, in order to effect the game state properly
    # not changing the "cache" will break queries
    # but not changing the texture will break the visual state
  
  class GameObjectData
    attr_reader :name, :mesh_name, :material_name
    
    def initialize(name, mesh_name, material_name)
      @name = name
      @mesh_name = mesh_name
      @material_name = material_name
    end
  end
  
  
  class MeshData
    attr_reader :mesh_name
    
    def initialize(mesh_name)
      @mesh_name = mesh_name
    end
  end
  
end

table = QueryTable.new
table.objects["obj_name"].mesh_name
table.objects["obj_name"].material_name
# table.objects["obj_name"].transform   (need to go to texture to resolve that)

table.meshes["mesh_name"]

table.mesh_query(:)

table.find_object("")



# query methods across all entities
class Entity
  class << self
    
    attr_accessor :cache
    # @cache is a class instance variable,
    # made publically accessible via attr_accessor.
    # Public access used to pass in DataCache from the outside world,
    # but access to the API should always be done via these methods.
  
    def find(obj_name_or_id)
      return @cache.find_object(obj_name_or_id
    end
    
    def find_by_id(obj_id)
      return @cache.find_object_by_id(obj_id)
    end
    
    def find_by_name(obj_name)
      return @cache.find_object_by_name(obj_name)
    end
    
    def mesh_id_to_name(mesh_id)
      return @cache.mesh_id_to_name(mesh_id)
    end
    
    def mesh_name_to_id(mesh_name)
      
    end
    
    # @@environment is a class variable, instance of VertexAnimationBatch
    # Just access this directly and use it, in any instance of Entity
    # or any instance of a subclass of Entity
    def environment=(env)
      @@environment = env
    end
    
    
  end
end

# methods on a particular entity
class Entity
  # Entity (aka GameObject) is created from a query into all available Entities.
  # 
  # How do you create a new Entity at runtime?
  # Something that was not specified by explicitly placing it in Blender?
  # (clone or dup an existing object - see example code below)
  def initialize(entity_data, transform_matrix)
    # @name = name
    @data = entity_data
    @transform = transform_matrix
    
    # does data need to be written back to the texture?
    @dirty = false
  end
  
  # Specify the mesh to use for a given object, 
  def mesh_name=(mesh_name)
    entity_data = @@foo.find_object_by_name(@data.object_name)
    mesh_i = @@foo.mesh_name_to_id(mesh_name)
    
    @@environment.set_entity_mesh(entity_data.index, mesh_i)
    # TODO: implement VertexAnimationBatch#set_entity_mesh
    # ^ need to update the cache when you change the underlying data, or queries will break
      # does this data need to propagate back to Blender?
      # should it be saved to disk? (likely NO)
    
    @dirty = true
  end
  
  # perform decomposition once when the entity data is pulled from the texture data. then once you have the separate components of the transform stored here, you can just set the matrix data in the texture using VertexAnimationBatch#set_entity_transform(i, mat)
  # (not sure what the opposite of the matrix decomposition function is, but I don't think I have that yet)
  # TODO: implement inverse of matrix decomposition (components -> mat4x4)
  
  
  # Rather than set the transform data from here -> image -> texture each time an object in manipulated, do all Entities together at the end of the update step - array-processing should make it faster, I think (like data driven design)
  # (see example code below)
  
  def position
    return @position
  end
  
  def position=(value)
    @position = value
    
    @transform = recompute_transform_matrix(@position, @orientation, @scale)
    # @environment.set_entity_transform(@data.index, @transform)
    @dirty = true
  end
  
  def orientation
    return @orientation
  end
  
  def orientation=(value)
    @orientation = value
    
    @transform = recompute_transform_matrix(@position, @orientation, @scale)
    # @environment.set_entity_transform(@data.index, @transform)
    @dirty = true
  end
  
  def scale
    return @scale
  end
  
  def scale=(value)
    @scale = value
    
    @transform = recompute_transform_matrix(@position, @orientation, @scale)
    # @environment.set_entity_transform(@data.index, @transform)
    @dirty = true
  end
  
  # can still get / set the entire transform matrix if you want,
  # but this is not intended to be the primary API
  def transform
    return @transform
  end
  
  def transform=(value)
    raise "Argument must be a GLM::Mat4" unless value.is_a? GLM::Mat4
    
    @transform = value
    # @environment.set_entity_transform(@data.index, @transform)
    @dirty = true
  end
  
  
  
  def recompute_transform_matrix
    # reference OpenFrameworks Node class
    # to see how this sort of thing can be implemented
    
  end
  
  
  
  
  attr_accessor :dirty
  def dirty?
    return @dirty
  end
  
end


class Foo
  def initialize(data_cache, vertex_animation_batch)
    
  end
end


data_cache = DataCache.new(json_filepath)

Foo.new(data_cache, @environment)

game_objects = []

entity = foo.find_by_name(name)
new_obj = entity.clone() # not sure if the interface should be clone or dup
  # ^ when you create the new object, make sure to create a new entry in the object data stores, both the cache and textures need to be updated. BUT only their in-memory representation, and not the representation on disk.
  # the on-disk representation governs only the initial state @ t=0, which should be controlled by Blender (at least that's what I think for now)
new_obj.transform = Transform.identity
new_obj.position = GLM::Vec3.new(0,0,0)

game_objects << entity


# save transforms to image all at once
# (can later convert Entity to a C++ type and iterate though an array - fast!)
# (can skip this phase entirely if the C++ type uses the in-memory image bits to store data - union type would be extremely useful)
updating_objects = game_objects.collect{|entity| entity.dirty? }

updating_objects.each do |entity|
  entity.dirty = false
  @environment.set_entity_transform(@entity.object_index, @entity.transform)
end


# send image to GPU texture, if image has been updated
# (not sure how to implement this check if sharing image data to C++ objects... maybe just need to make sure sending the image data to the GPU is always done every frame, and just make it as fast as possible?)
unless updating_objects.empty?
  # currently, this transfer from CPU to GPU happens within RubyOF::CPP_Callbacks.set_entity_transform() - every time the entity transform is updated, the entire image is pushed out to the GPU again. That is not efficient, and explains why for many entities, we start to get slowdown.
  # Maybe if I optimize this, I can go even faster?
  
end



  # if the transforms have been changed, update the transform texture
  # if the meshes have been altered...
    # wait - the actual mesh data (vertex data) should never be edited in Ruby
  # so you only ever have to consider editing the transform texture
    # mesh bindings are also encoded in the transform texture
  
  
  # CPU -> GPU data flow:
    # rarely need to re-send mesh data (only if the data was updated by Blender)
    # need to send the object data exactly once every frame





