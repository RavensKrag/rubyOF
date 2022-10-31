
# 
# 
# Frontend object-oriented API for entities / meshes
# 
# 

# interface for managing entity data
class RenderEntityManager
  def initialize(batch)
    @batches = batch
  end
  
  # Retrieve entity by name
  def [](entity_name)
    # check all batches for possible name matches (some entries can be nil)
    entity_idx_list = 
      @batches.collect do |batch|
        batch[:names].entity_name_to_scanline(entity_name)
      end
    
    # find the first [batch, idx] pair where idx != nil
    batch, entity_idx = 
      @batches.zip(entity_idx_list)
      .find{ |batch, idx| !idx.nil? }
    
    if entity_idx.nil?
      raise "ERROR: Could not find any entity called '#{entity_name}'"
    end
    
    # puts "#{entity_name} => index #{entity_idx}"
    
    entity_ptr = batch[:entity_cache].get_entity(entity_idx)
    mesh_name = batch[:names].mesh_scanline_to_name(entity_ptr.mesh_index)
    mesh = MeshSprite.new(batch, mesh_name, entity_ptr.mesh_index)
    
    return RenderEntity.new(batch, entity_name, entity_idx, entity_ptr, mesh)
  end
  
  
  include Enumerable
  # ^ provides each_with_index, group_by, etc
  #   all built on top of #each
  
  # return each and every entity defined across all batches
  def each() # &block
    return enum_for(:each) unless block_given?
    
    @batches.each do |batch|
      num_scanlines = batch[:entity_data][:pixels].height
      
      scanline_idxs = num_scanlines.times.map{|i| i }
      
      entity_names = 
        scanline_idxs.collect do |i|
          batch[:names].entity_scanline_to_name(i)
        end
      
      entity_names.zip(scanline_idxs)
      .select{ |name, i| name != nil }
      .each do |entity_name, entity_idx|
        # puts "#{entity_name} => index #{entity_idx}"
        
        entity_ptr = batch[:entity_cache].get_entity(entity_idx)
        mesh_name = batch[:names].mesh_scanline_to_name(entity_ptr.mesh_index)
        mesh = MeshSprite.new(batch, mesh_name, entity_ptr.mesh_index)
        
        yield RenderEntity.new(batch, entity_name, entity_idx, entity_ptr, mesh)
        
        # ^ using self[] is very inefficient, as it must traverse all batches again, to find one that contains the target name.
        # TODO: can we create a private method that would allow us to go directly to the entity at this stage?
      end
    end
  end
  
end

# Access a group of different meshes, as if they were sprites in a spritesheet.
# 
# Creates an abstraction over the set of ofFloatPixels and ofTexture objects
# needed to manage the vertex animation texture set of meshes.
# Notice that similar to sprites in a spritesheet, many meshes are packed
# into a single texture set.
# 
# As mesh sprites are defined relative to some (entity, mesh) texture pair, 
# it's really the render batch that is the 3D analog of the 2D spritesheet.
class MeshSpriteManager
  def initialize(batch)
    @batch = batch
  end
  
  # access 'sprite'  by name
  # (NOTE: a 'sprite' can be one or more rows in the spritesheet)
  def [](target_mesh_name)
    # check all batches for possible name matches (some entries can be nil)
    mesh_idx_list = 
      @batches.collect do |batch|
        @batch[:names].mesh_name_to_scanline(target_mesh_name)
      end
    
    # find the first [batch, idx] pair where idx != nil
    batch, mesh_idx = 
      @batches.zip(mesh_idx_list)
      .find{ |batch, idx| !idx.nil? }
    
    
    if mesh_idx.nil?
      raise "ERROR: Could not find any mesh called '#{target_mesh_name}'"
    end
    # p mesh_idx
    
    return MeshSprite.new(batch, target_mesh_name, mesh_idx)
  end
end





class RenderEntity
  extend Forwardable
  
  attr_reader :batch, :name, :index
  
  def initialize(batch, name, index, entity_data, mesh)
    @batch = batch
    @name = name
    @index = index # don't typically need this, but useful to have in #inspect for debugging
    @entity_data = entity_data
    
    @mesh = mesh # instance of the MeshSprite class
  end
  
  def to_s
    # TODO: implement me
    super()
  end
  
  def inspect
    # TODO: implement me
      # can't reveal the full chain of everything, because it contains a reference to the RenderBatch, which is linked to a whole mess of data. if you try to print all of that to stdout when logging etc, it is way too much data to read and understand
      # (maybe the solution is to actually change RenderBatch#inspect instead?)
    super()
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
    raise "Input mesh must be a MeshSprite object" unless mesh.is_a? MeshSprite
    
    # NOTE: entity textures can only reference mesh indicies from within one set of mesh data textures
    unless mesh.batch.equal? @mesh.batch # test pointers, not value
      msg [
        "ERROR: Entities can only use meshes from within one batch, but attempted to assign a new mesh from a different batch.",
        "Current: '#{@mesh.name}' from '#{@mesh.batch.name}'",
        "New:     '#{mesh.name}' from '#{mesh.batch.name}'",
      ]
      
      raise msg.join("\n")
    end
    
    @entity_data.mesh_index = mesh.index
    @mesh = mesh
  end
  
  def mesh
    return @mesh
  end
end



# NOTE: For now, MeshSprite does not actually contain any pointers to mesh data, because mesh data is not editable. When the ability to edit meshes is implemented, that extension should live in this class. We would need a system similar to EntityCache to allow for high-level editing of the image-encoded mesh data.
class MeshSprite
  attr_reader :batch, :name, :index
  
  def initialize(parent_batch, name, index)
    @batch = parent_batch
    
    @name = name
    @index = index
  end
end
