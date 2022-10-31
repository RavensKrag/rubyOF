# 
# 
# Spatial query API
# 
# 

# enable spatial queries
class Space
  def initialize(entities)
    @entities = entities
    # @data = data
    
    @groups = nil
    @static_entities  = []
    @dynamic_entities = []
    
    # TODO: encode which collections are dynamic and which are static in some other way. don't want to have the names of the collections hard coded like like.
    @static_collection_names  = ['Tiles']
    @dynamic_collection_names = ['Characters']
  end
  
  def setup
    @groups = 
      @entities.group_by do |render_entity|
        render_entity.batch.name
      end
    # => Hash (batch_name => [e1, e2, e3, ..., eN])
    
    
    @static_entities = 
      @static_collection_names.collect{ |name|
        # For static entities, you only care about what type of thing is there
        # you don't need the actual RenderEntity object
        # because you will never change the properties of the entity at runtime.
        # 
        # We will use the name of the mesh data as a 'type'
        list = @groups[name]
        if list.nil?
          # raise "ERROR: no group found with name #{name.inspect}. Here are the known group names: #{@groups.keys.inspect}"
          nil
        else
          list.collect do |render_entity|
            [render_entity.mesh.name, render_entity.position]
          end
        end
      }.compact.flatten(1).collect do |name, position|
        StaticPhysicsEntity.new(name, position)
      end
    
    self.update()
  end
  
  def update
    # for dynamic entities, you need the actual entity object,
    # so you can make changes as necessary.
    # In the future, you want access to the gameplay entity,
    # but we haven't implemented those.
    # Just store name for now, for symmetry with static entities.
    @dynamic_entities = 
      @dynamic_collection_names.collect{ |name|
        list = @groups[name]
        if list.nil?
          # raise "ERROR: no group found with name #{name.inspect}. Here are the known group names: #{@groups.keys.inspect}"
          nil
        else
          list.collect do |render_entity|
            [render_entity.name, render_entity.position]
          end
        end
      }.flatten(1).collect do |name, position|
        DynamicPhysicsEntity.new(name, position)
      end
  end
  
    # in the future, do we want to get the RenderEntity,
    # or do we want the entity with the gameplay logic?
    # 
    # probably the one with gameplay logic
    
    # seems like all static entities of a given type
    # should share one gameplay entity
    # (separate transforms can still be stored per-RenderEntity)
    # (but core gameplay rules would be the same)
    
  
  
  # what type of tile is located at the point 'pt'?
  # Returns a list of title types (mesh datablock names)
  def point_query(pt, physics_type: :all)
    puts "point query @ #{pt}"
    
    entity_list = 
      case physics_type
      when :static
        @static_entities
      when :dynamic
        @dynamic_entities
      when :all
        @static_entities + @dynamic_entities
      end
    # p entity_list
    
    entity_list.select{|e| e.position == pt }
  end
end



# TODO: consider separate api for querying static entities (tiles) vs dynamic entities (gameobjects)
  # ^ "tile" and "gameobject" nomenclature is not used throughout codebase.
  #   may want to just say "dynamic" and "static" instead

class PhysicsEntity
  attr_reader :name, :position
  
  def initialize(static_or_dynamic, name, position)
    @static_or_dynamic = static_or_dynamic
    @name = name
    @position = position
    
    # TODO: add orientation (N, S, E, W) or similar, for gameplay logic. probably do not want to use the quaternion orientation from ofNode.
  end
  
  def static?
    return @static_or_dynamic == :static
  end
  
  def dynamic?
    return @static_or_dynamic == :dynamic
  end
  
  def gameplay_entity
    if static?
      return nil
    else
      return nil
    end
  end
end

class StaticPhysicsEntity < PhysicsEntity
  def initialize(name, position)
    super(:static, name, position)
  end
  
  # all meshes are solid for now
  # (may need to change this later when adding water tiles, as the character can occupy the same position as a water tile)
  def solid?
    return true
  end
end

class DynamicPhysicsEntity < PhysicsEntity
  def initialize(name, position)
    super(:dynamic, name, position)
  end
  
  # all meshes are solid for now
  # (may need to change this later when adding water tiles, as the character can occupy the same position as a water tile)
  def solid?
    return true
  end
end

