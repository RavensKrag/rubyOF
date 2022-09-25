def test
  $world = World.new
  
  
  # retrieve entity from world
  entity = $world.entities['CharacterTest']
  
  
  # move entity
  entity.position += GLM::Vec3.new(1,0,0)
  
  
  # re-assign mesh
  # (arbitrary re-assigment of single mesh entity)
  entity.mesh = entity.mesh.batch['Cube.010']
  
  
  
  
  
  # re-assign mesh
  # (animation prototype)
  
  # declare animation frame name pattern, that detects basename and frame number
  # if you match against the pattern
    # increment the frame number
    # make sure frame number doesn't exceed maximum frame number
    # use the pattern to create a new sprite name
    # find the sprite with the desired name
    # assign the new MeshSprite to the entity
  # (this assumes frames play back with uniform time between frames, which is not true universally, but this would be a good way to start thinking about how to implement animations)
  if entity.mesh.frame_of_animation?
    # if the current mesh is a frame of an animation
    # then advance to the next frame
    i = entity.mesh.frame_number + 1
    entity.mesh.batch[entity.mesh.basename + ".frame#{i}"]
    
    
    entity.mesh = mesh
  end
  
end
# TODO: sketch how these systems connect to lighting
# TODO: sketch how these systems connect to viewport camera
# TODO: sketch how these systems connect to render pipeline
# TODO: sketch how these systems connect to materials / shaders
# TODO: make sure there's nothing else I missed from World.rb that needs to come over


# TODO: read over history system and make sure it still works
# TODO: test history / time travel systems




class World
  attr_reader :batches, :transport, :history, :entities, :sprites, :space
  
  def initialize(geom_texture_directory)
    # one StateMachine instance, transport, etc
    # but many collections with EntityCache + pixels + textures + etc
    
    
    # 
    # backend data
    # 
    
    # TODO: consider creating new 'batches' collection class, to prevent other code from adding elements to the @batches array - should be read-only from most parts of the codebase
    
    buffer_length = 3600
    
    
    @batches = 
      geom_texture_directory.children
      .select{ |file| file.basename.to_s.end_with? ".cache.json" }
      .collect do |file|
        # p file
        name, _, _ = file.basename.to_s.split('.')
        RenderBatch.new(geom_texture_directory, name)
      end
    
    @batches.each do |b|
      b.setup(buffer_length)
    end
    
    
    
    # 
    # frontend systems
    # (provide object-oriented API for manipulating render entities)
    # (query entities and meshes by name)
    # 
    
    @entities = RenderEntityManager.new(@batches)
    @sprites  = MeshSpriteManager.new(@batches)
    
    
    
    # 
    # spatial query interface
    # (query entities by position in 3D space)
    # 
    
    @space = Space.new(@entities)
    
    
    
    # 
    # core inteface to backend systems
    # (move data from EntityCache into Textures needed for rendering)
    # 
    
    @shared_data = Context.new(buffer_length)
    
    @transport = TimelineTransport.new(@shared_data, @state_machine)
    # ^ methods = [:play, :pause, :seek, :reset]
    
    @history = History.new(@batches, @shared_data)
      h1 = SaveHelper.new(@history, @shared_data)
      h2 = LoadHelper.new(@history)
    
    
    
    @state_machine = StateMachine.new
    @state_machine.setup do |s|
      s.define_states(
        States::Initial.new(      @state_machine),
        States::GeneratingNew.new(@state_machine, @shared_data, h1),
        States::ReplayingOld.new( @state_machine, @shared_data, @transport, h2),
        States::Finished.new(     @state_machine, @shared_data, @transport, h2)
      )
      
      s.initial_state States::Initial
      
      s.define_transitions do |p|
        p.on_transition :any_other => States::Finished do |ipc|
          puts "finished --> (send message to blender)"
          
          ipc.send_to_blender({
            'type' => 'loopback_finished',
            'history.length' => @shared_data.history.length
          })
        end
        
        p.on_transition States::GeneratingNew => States::ReplayingOld do |ipc|
          # should cover both pausing and pulling the read head back
          
          ipc.send_to_blender({
            'type' => 'loopback_paused_new',
            'history.length'      => @shared_data.history.length,
            'history.frame_index' => @shared_data.frame_index
          })
        end
      end
    end
    
    
    
    
    
    
    # where does the data move from :pixels to :cache ?
    # It's not in this file.
    # Should it be here? It might make the information flow clearer.
    
    # currently in VertexAnimationTextureSet#update
      # /home/ravenskrag/Desktop/gem_structure/bin/projects/blender_iso_game/lib/vertex_animation_texture_set.rb
      # probably want to keep the logic there because it also handles serialization (disk -> pixels -> texture and cache)
      # but maybe we call the update from here instead of the current location?
    
    # World#update -> VertexAnimationTextureSet#update
  end
  
  
  
  def update(ipc, &block)
    @state_machine.update(ipc)
    
    if @transport.playing?
      @shared_data.bind_code(block)
      # TODO: only bind new code when necessary. if you rebind too much, then you can't resume execution in the expected way (will overwrite fiber).
      @state_machine.next
    end
  end
  
  def on_reload_code(ipc)
    
  end
  
  def on_reload_data(ipc)
    
  end
  
  # where does this belong?
  def on_crash(ipc)
    @shared_data.frame_index -= 1
    @transport.seek(@shared_data.frame_index)
  end
  
end





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
        @groups[name].collect do |render_entity|
          [render_entity.mesh.name, render_entity.position]
        end
      }.flatten.each do |name, position|
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
        @groups[name].collect do |render_entity|
          [render_entity.name, render_entity.position]
        end
      }.flatten.each do |name, position|
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
    
    entity_list.select{|e| e.position == pt }
  end
end



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
end

class DynamicPhysicsEntity < PhysicsEntity
  def initialize(name, position)
    super(:dynamic, name, position)
  end
end










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
  def [](target_entity_name)
    # check all batches for possible name matches (some entries can be nil)
    entity_idx_list = 
      @batches.collect do |batch|
        @batch[:names].entity_name_to_scanline(target_entity_name)
      end
    
    # find the first [batch, idx] pair where idx != nil
    batch, entity_idx = 
      @batches.zip(entity_idx_list)
      .find{ |batch, idx| !idx.nil? }
    
    if entity_idx.nil?
      raise "ERROR: Could not find any entity called '#{target_entity_name}'"
    end
    
    # puts "#{target_entity_name} => index #{entity_idx}"
    
    entity_ptr = batch[:entity_cache].get_entity(entity_idx)
      # puts target_entity_name
      # puts "entity -> mesh_index:"
      # puts entity_ptr.mesh_index
    mesh_name = batch[:names].mesh_scanline_to_name(entity_ptr.mesh_index)
    mesh = MeshSprite.new(batch, mesh_name, entity_ptr.mesh_index)
    
    return RenderEntity.new(batch, target_entity_name, entity_idx, entity_ptr, mesh)
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
  
  # all meshes are solid for now
  # (may need to change this later when adding water tiles, as the character can occupy the same position as a water tile)
  def solid?
    return true
  end
end









# 
# 
# Backend - transport entity data to GPU, across all timepoints in history
# 
# 


# based on VertexAnimationTextureSet
# stores render data, but does not perform the actual rendering
class RenderBatch
  include RubyOF::Graphics
  
  def initialize(data_dir, name)
    @data_dir = data_dir
    @name = name
    
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
      
      :entity_cache => RubyOF::Project::EntityCache.new, # size == num dynamic entites
      
      :entity_history => HistoryBuffer.new,
      
      :names => TextureJsonCache.new, # <- "json file"
        # ^ convert name to scanline AND scanline to name
      
      :geometry => BatchGeometry.new # size == max tris per mesh in batch
      
    })
    
  end
  
  def setup(buffer_length)
    json_file_path    = @data_dir/"#{@name}.cache.json"
    position_tex_path = @data_dir/"#{@name}.position.exr"
    normal_tex_path   = @data_dir/"#{@name}.normal.exr"
    entity_tex_path   = @data_dir/"#{@name}.entity.exr"
    
    load_mesh_textures(position_tex_path, normal_tex_path)
    load_entity_texture(entity_tex_path)
    load_json_data(json_file_path)
    
    
    # NOTE: mesh data dimensions could change on load, but BatchGeometry assumes that the number of verts / triangles in the mesh is constant
    vertex_count = @storage[:mesh_data][:pixels][:positions].width.to_i
    @storage[:geometry].generate vertex_count
    
    @storage[:cache].load @storage[:entity_data][:pixels]
    
    
    @storage[:entity_history].setup(
      buffer_length: buffer_length,
      frame_width:   @storage[:entity_data][:pixels].width,
      frame_height:  @storage[:entity_data][:pixels].height
    )
  end
  
  
  # allow hash-style access to the FixedSchemaTree
  # (FixedSchemaTree not not allow adding elements, so this is fine)
  def [](key)
    return @storage[key]
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


end

    



















# control timeline transport (move back and forward in time)
class TimelineTransport
  def initialize(shared_data, state_machine)
    @state_machine = state_machine
    @data = shared_data
    @frame = 0
    @play_or_pause = :paused
  end
  
  # if playing, pause forward playback
  # else, do nothing
  def pause
    @play_or_pause = :paused
  end
  
  # if paused, run forward
  # 'running' has different behavior depending on the currently active state
  # may generate new data from code,
  # or may replay saved data from history buffer
  def play
    @play_or_pause = :playing
  end
  
  def paused?
    return @play_or_pause == :paused
  end
  
  def playing?
    return @play_or_pause == :playing
  end
  
  # instantly move to desired frame number
  # (moving frame-by-frame in blender is implemented in terms of #seek)
  def seek(frame_number)
    @data.frame_index = frame_number
    @state_machine.seek(@data.frame_index)
  end
  
  # reset the timeline back to t=0 and clear history
  def reset
    
  end
end

# state shared between TimelineTransport and the StateMachine states,
# but that is not revealed to the outside world
class Context
  attr_accessor :frame_index
  attr_accessor :block
  
  def initialize(buffer_length)
    @buffer_length = buffer_length
    @frame_index = 0
    
    # @final_frame = ???
    # TODO: implement @final_frame and outside access
  end
  
  def bind_code(&block)
    @block = block
  end
  
  def final_frame
    @buffer_length - 1
  end
  
  # TODO: implement #history.length
end

# helps to save stuff from code into the buffer, so we can time travel later
class SaveHelper
  # TODO: re-name this class. it actually does some amount of loading too, so that it can resume fibers...
  def initialize(history_controller, context)
    @history = history_controller
    @context = context
  end
  
  def frame(&block)
    if @context.frame_index < @context.final_frame
      # resuming
      
      # if manually stepping forward, we'll be able to see the transition
      # but otherwise, this transition will be silent,
      # because there is no Fiber.yield in this branch.
      # 
      # (keeps logs clean unless you really need the info)
      
      # (skip this frame)
      # don't run the code for this frame,
      # so instead update the transforms
      # based on the history buffer
      
      # Can't just jump in the buffer, because we need to advance the Fiber.
      # BUT we may be able to optimize to just loading the last old state
      # before we need to generate new states.
      
      @context.frame_index += 1
      
      puts "#{@context.frame_index.to_s.rjust(4, '0')} resuming"
      
      @history.load_state_at_current_frame
      
    else # [@history.length-1, inf]
      # actually generating new state
      @history.snapshot_gamestate_at_current_frame
      
      # p [@context.frame_index, @history.length-1]
      # puts "history length: #{@history.length}"
      
      @context.frame_index += 1
      
      frame_str = @context.frame_index.to_s.rjust(4, '0')
      src_file, src_line = block.source_location
      
      file_str = src_file.gsub(/#{GEM_ROOT}/, "[GEM_ROOT]")
      
      puts "#{frame_str} new state  #{file_str}, line #{src_line} "
      
      # p block
      # puts "--------------------------------"
      # p block.source_location
      block.call()
      # puts "--------------------------------"
      
      Fiber.yield
    # elsif @executing_frame > @history.length
    #   # scrubbing in future space
    #   # NO-OP
    #   # (pretty sure I need both this logic and the logic in Finished)
    # else
    #   # initial state??
    #   # not sure what's left
    end
    
  end
end

# helps to load data from the buffer
class LoadHelper
  def initialize(history_buffer)
    @history = history_buffer
  end
  
  def load_state_at_current_frame
    @history.load_state_at_current_frame
  end
end

# TODO: consider consolidating all high-level buffer operations in one place
class History
  def initialize(batches, context)
    @batches = batches
    @context = context
  end
  
  # # create buffer of a certain size
  # def setup
  #   # NO-OP - done in RenderBatch
  # end
  
  # save current frame to buffer
  def snapshot
    @batches.each do |b|
      b[:entity_cache].update b[:entity_pixels]
      b[:entity_history][@context.frame_index] = b[:entity_pixels]
    end
    
    # @state[:cache].update @state[:pixels]
    # @buffer[frame_index] = @state[:pixels]
  end
  
  # load current frame from buffer
  def load
    @batches.each do |b|
      b[:entity_pixels].copy_from b[:entity_history][@context.frame_index]
      b[:entity_cache].load b[:entity_pixels]
    end
    # ^ Above code is much harder to read than the previous prototype below
    #   because there are no colors to direct attention,
    #   due to the lack of sigils and syntax highlighting.
    #   How can this be refactored to be more easily skimmed? 
    #   (same for #snapshot)
    
    # cached_data = @buffer[@context.frame_index]
    # @state[:pixels].copy_from cached_data
    # @state[:cache].load @state[:pixels]
    
    
    
    
    
    
    # TODO: find a better interface for loading
      # when I save the frame, it looks just like array saving,
      # but when I load the frame I have to call #copy_from.
      # Is there a way to make this more symmetric?
  end
  
  # delete arbitrary frame from buffer
  def delete
    # @buffer.delete(@context.frame_index)
  end
  
  # create a new buffer using a slice of the current buffer
  def branch
     
  end
end










# abstract definition of state machine structure
# + update     triggers state transitions
# + next       delegate to current state (see 'States' module below)
class StateMachine
  extend Forwardable
  
  def initialize()
    
  end
  
  def setup(&block)
    @states = []
    @transitions = [] # [prev_state, next_state, Proc]
    
    helper = DSL_Helper.new(@states, @transitions)
    block.call helper
    
    @previous_state = nil
    @current_state = helper.initial_state
  end
  
  # update internal state and fire state transition callbacks
  def update(ipc)
    match(@previous_state, @current_state, transition_args:[ipc])
  end
  
  def_delegators :@current_state, :next
  # TODO: Implement custom delegation using method_missing, so that the methods to be delegated can be specified on setup. Should extend the DSL with this extra functionality. That way, the state machine can become a fully reusable component.
  
  
  # trigger transition to the specified state
  def transition_to(new_state_klass)
    if not @states.include? new_state_klass
      raise "ERROR: '#{new_state_klass.to_s}' is not one of the available states declared using #define_states. Valid states are: #{@states.inspect}"
    end
    
    new_state = new_state_klass.new(self)
    
    puts "transition: #{@current_state.class} -> #{new_state.class}"
    
    new_state.on_enter()
    @previous_state = @current_state
    @current_state = new_state
  end
  
  class DSL_Helper
    attr_reader :initial_state
    
    def initialize(states, transitions)
      @states = states
      @transitions = transitions
    end
    
    def define_states(*args)
      # ASSUME: all arguments should be objects that implement the desired semantics of a state machine state. not exactly sure what that means rigorously, so can't perform error checking.
      @states = args
    end
    
    def initial_state(state_class)
      if @states.empty?
        raise "ERROR: Must first declare all possible states using #define_states. Then, you can specify one of those states to be the initial state, by providing the class of that state object."
      end
      
      unless state_defined? state_class
        raise "ERROR: '#{state_class.to_s}' is not one of the available states declared using #define_states. Valid states are: #{ @states.map{|x| x.class.to_s} }"
      end
      
      @initial_state = find_state(state_class)
    end
    
    def define_transitions(&block)
      helper = PatternHelper.new(@states, @transitions)
      block.call helper
    end
    
    
    class PatternHelper
      def initialize(states, transitions)
        @states = states
        @transitions = transitions
      end
      
      # States::StateOne => States::StateTwo do ...
      def on_transition(pair={}, &block)
        prev_state_id = pair.keys.first
        next_state_id = pair.values.first
        
        [prev_state_id, next_state_id].each do |state_class|
          unless(state_class == :any || 
                 state_class == :any_other ||
                 state_defined? state_class
          )
            raise "ERROR: State transition was not defined correctly. Given '#{state_class.to_s}', but expected either one of the states declared using #define_states, or the symbols :any or :any_other, which specify sets of states. Defined states are: #{ @states.map{|x| x.class.to_s} }"
          end
        end
        
        @transitions << [ prev_state_id, next_state_id, block ]
      end
    end
  end
  
  
  private
  
  
  def match(p,n, transition_args:[])
    @patterns.each do |prev_state_id, next_state_id, proc|
      # state IDs can be the class constant of a state,
      # or the symbols :any or :any_other
      # :any matches any state (allowing self loops)
      # :any_other matches any state other than the other specified state (no self loop)
      # if you specify :any_other in both slots, the callback will trigger on all transitions that are not self loops
      
      cond1 = (
        (prev_state_id == :any) || 
        (prev_state_id == :any_other && p != n) ||
        (p == prev_state_id)
      )
      
      cond2 = (
        (next_state_id == :any) || 
        (next_state_id == :any_other && n != p) ||
        (n == next_state_id)
      )
      
      if cond1 && cond2
        proc.call(*args)
      end
    end
  end
  
  # return the first state object which is a subclass of the given class
  def find_state(state_class)
    return @states.find{|x| x.is_a? state_class }
  end
  
  # returns true if @states contains an object of the specified class
  def state_defined?(state_class)
    return find_state(state_class) != nil
  end
end

# class DefaultState
#   def initialize(state_machine, transport, context)
#     @state_machine = state_machine
#     @transport = transport
#     @context = context
#   end
# end

     
# states used by state machine defined below
# ---
# should we generate new state from code or replay old state from the buffer?
# that depends on the current system state, so let's use a state machine.
# + next       advance the system forward by 1 frame
# + seek       jump to an arbitrary frame
module States
  class Initial < DefaultState
    # initialized once when state machine is setup
    def initialize(state_machine)
      @state_machine = state_machine
    end
    
    # called every time we enter this state
    def on_enter
      
    end
    
    # step forward one frame
    # (name taken from Enumerator#next, which functions similarly)
    def next
      @state_machine.transition_to GeneratingNew
    end
    
    # jump to arbitrary frame
    def seek(frame_number)
      
    end
  end
  
  class GeneratingNew < DefaultState
    # initialized once when state machine is setup
    def initialize(state_machine, shared_data, save_helper)
      @state_machine = state_machine
      @context = shared_data
      @save_helper = save_helper
      
      @f1 = nil
      @f2 = nil
    end
    
    # called every time we enter this state
    def on_enter
      @f1 = nil
      @f2 = nil
    end
    
    # step forward one frame
    def next
      @f2 ||= Fiber.new do
        # This Fiber wraps the block so we can resume where we left off
        # after Helper pauses execution
        @context.block.call(@save_helper)
      end
      
      @f1 ||= Fiber.new do
        # Execute @f2 across many different frames, instead of all at once
        while @f2.alive?
          @f2.resume()
          Fiber.yield
        end
      end
      
      if @f1.alive?
        # if there is more code to run, run the code to generate new state
        @f1.resume()
      else
        # else, code has completed
        @state_machine.transition_to Finished
      end
    end
    
    # jump to arbitrary frame
    def seek(frame_number)
      
    end
  end
  
  class ReplayingOld < DefaultState
    # initialized once when state machine is setup
    def initialize(state_machine, shared_data, transport, load_helper)
      @state_machine = state_machine
      @context = shared_data
      @transport = transport
      @load_helper = load_helper
    end
    
    # called every time we enter this state
    def on_enter
      
    end
    
    # step forward one frame
    def next
      if @context.frame_index >= @context.final_frame
        # ran past the end of saved history
        # must retun to generating new data from the code
        
        # @context.transition_and_rerun(GeneratingNew, :update, &block)
        @state_machine.transition_to GeneratingNew
        @state_machine.next
        
      else # @context.frame_index < @context.final_frame
        # otherwise, just load the pre-generated state from the buffer
        
        @context.frame_index += 1
        @load_helper.load_state_at_current_frame
        
        # stay in state ReplayingOld
      end
    end
    
    # jump to arbitrary frame
    def seek(frame_number)
      # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
      
      if frame_number.between?(0, @context.final_frame) # [0, len-1]
        # if range of history buffer, move to that frame
        
        @context.frame_index = frame_number
        @load_helper.load_state_at_current_frame
        
        puts "#{@context.frame_index.to_s.rjust(4, '0')} old seek"
        
        # stay in state ReplayingOld
        
      elsif frame_number > @context.final_frame
        # if outside range of history buffer, snap to final frame
        
        # delegate to state :generating_new
        @context.frame_index = @context.final_frame
        @load_helper.load_state_at_current_frame
        
        puts "#{@context.frame_index.to_s.rjust(4, '0')} old seek"
        
        @transport.pause
        
        # stay in state ReplayingOld
        
      else # frame_number < 0
        raise "ERROR: Tried to seek to negative frame => (#{frame_number})"
      end
      # TODO: Blender frames can be negative. should handle that case too.
          
    end
  end
  
  class Finished < DefaultState
    # initialized once when state machine is setup
    def initialize(state_machine, shared_data, transport, load_helper)
      @state_machine = state_machine
      @context = shared_data
      @transport = transport
      @load_helper = load_helper
    end
    
    # called every time we enter this state
    def on_enter
      puts "#{@context.frame_index.to_s.rjust(4, '0')} initial"
    end
    
    # step forward one frame
    def next
      # instead of advancing the frame, or altering state,
      # just pause execution again
      @transport.pause
    end
    
    # jump to arbitrary frame
    def seek(frame_number)
      if frame_number >= @context.final_frame
        # NO-OP
      else
        # @context.transition_and_rerun ReplayingOld, :seek, frame_number
        @state_machine.transition_to ReplayingOld
        @transport.seek(frame_number)
        
      end
    end
  end
end





# stores the data for time traveling
class HistoryBuffer
  # attr_reader :state, :buffer
  # protected :state
  # protected :buffer
  
  # TODO: use named arguments, because the positions are extremely arbitrary
  def initialize(mom=nil, slice_range=nil)
    if mom
      @max_num_frames = mom.max_num_frames
      self.setup(mom.state[:pixels],
                 mom.state[:texture],
                 mom.state[:cache]
      )
      slice_range.each do |i|
        @buffer[i].copy_from mom.buffer[i]
      end
    else
      @max_num_frames = 0
      @buffer = []
      @valid = []
    end
      
      # (I know this needs to save entity data, but it may not need to save mesh data. It depends on whether or not all animation frames can fit in VRAM at the same time or not.)
  end
  
  # TODO: remove @state and related variables from HistoryBuffer. should only be a storage data structure for a sequence of images over time. should not know anything about the specifics of the vertext animation texture system.
  def setup(buffer_length:3600, frame_width:9, frame_height:100)
    puts "[ #{self.class} ]  setup "
    
    @max_num_frames = buffer_length
    
    # # retain key data objects for entity state
    # @state = {
    #   :pixels => pixels,
    #   :texture => texture,
    #   :cache => cache
    # }
    
    # store data
    @buffer = Array.new(@max_num_frames)
    @buffer.size.times do |i|
      pixels = RubyOF::FloatPixels.new
      
      pixels.allocate(frame_width, frame_height)
      pixels.flip_vertical
      
      @buffer[i] = pixels
    end
    
    # create array of booleans to know which images store valid states
    @valid = Array.new(@buffer.size, false)
  end
  
  def length
    return @max_num_frames
  end
  
  alias :size :length
  
  def frame_width
    @buffer[0].width
  end
  
  def frame_height
    @buffer[0].height
  end
  
  # read from buffer
  # returns a reference to RubyOF::FloatPixels
  def [](frame_index)
    raise IndexError, "Index should be a non-negative integer. (Given #{frame_index.inspect} instead.)" if frame_index.nil?
    
    raise "Memory not allocated. Please call #{self.class}#setup first" if self.length == 0
    
    raise IndexError, "Index #{frame_index} outside the bounds of recorded frames: 0..#{self.length-1}" unless frame_index.between?(0, self.length-1)
    
    raise "Attempted to read garbage state. State at frame #{frame_index} was either never saved, or has since been deleted." unless @valid[frame_index]
    
    return @buffer[frame_index]
  end
  
  # save to buffer
  # stores a copy of the input data, rather than a reference as in Array#[]=
  def []=(frame_index, data)
    # TODO: raise exception of data is not RubyOF::FloatPixels instance
    
    raise IndexError, "Index should be a non-negative integer." if frame_index.nil?
    
    raise "Memory not allocated. Please call #{self.class}#setup first" if self.length == 0
    
    raise IndexError, "Index #{frame_index} outside of array bounds: 0..#{self.length-1}" unless frame_index.between?(0, self.length-1)
    
    data_size   = [data.width, data.height]
    buffer_size = [self.frame_width, self.frame_height]
    raise "Dimensions of provided frame data do not match the size of frames in the buffer. Provided: #{data_size.inspect}; Buffer size: #{buffer_size.inspect}" unless data_size == buffer_size
    
    @buffer[frame_index].copy_from data
    @valid[frame_index] = true
  end
  
  # delete data at index
  def delete(frame_index)
    @valid[frame_index] = false
  end
  
  # TODO: consider storing the current frame_count here, to have a more natural interface built around #<< / #push
  # (would clean up logic around setting frame data to not be able to set arbitrary frames, but that "cleaner" version might not actually work because of time traveling)
  
  
  # # TODO: implement this new interface
  # @buffer[frame_index] << @state[:pixels] # save data into history buffer
  # @buffer[frame_index] >> @state[:pixels] # load data from buffer into another image
  #   # + should I implement this on RubyOF::Pixels for all images?
  #   # + can this be patterned as a general "memory transfer operator" ?
    
  # @state[:pixels] << @buffer[frame_index] # load data from buffer into another image
  
  
  # image buffers are guaranteed to be the right size,
  # (as long as the buffer is allocated)
  # because of setup()
  
  
end
  # FIXME: recieving index -1
  # (should I interpret that as distance from the end of the buffer, or what? need to look into the other code on the critical path to figure this out)
  
  
  
  # OpenFrameworks documentation
    # use ofPixels::pasteInto(ofPixels &dst, size_t x, size_t y)
    # 
    # "Paste the ofPixels object into another ofPixels object at the specified index, copying data from the ofPixels that the method is being called on to the ofPixels object at &dst. If the data being copied doesn't fit into the destination then the image is cropped."
    
  
    # cropTo(...)
    # void ofPixels::cropTo(ofPixels &toPix, size_t x, size_t y, size_t width, size_t height)

    # This crops the pixels into the ofPixels reference passed in by toPix. at the x and y and with the new width and height. As a word of caution this reallocates memory and can be a bit expensive if done a lot.




end
