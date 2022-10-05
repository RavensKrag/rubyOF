# TODO: use this implementation instead of the current implementation
  # NOTE: this file was being loaded by the dynamic reload system before I wanted it to effect the main codebase. why was this being loaded?
# TODO: break this up into many files


# TODO: test history / time travel systems



# TODO: implement high-level interface for when one blender object is exported as mulitple entity / mesh pairs. in other words, you have one logical render entity, but the low-level system has many entities and many meshes that need to be managed.





class World
  extend Forwardable
  
  attr_reader :batches
  attr_reader :transport, :entities, :sprites, :space
  attr_reader :lights, :camera
  
  def initialize(geom_texture_directory)
    # one StateMachine instance, transport, etc
    # but many collections with EntityCache + pixels + textures + etc
    
    # 
    # backend data
    # 
    @batches = RenderBatchContainer.new(
      self, # link to the Window to allow accessing all other collections
      geometry_texture_directory: geom_texture_directory,
      buffer_length: 3600
    )
    
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
    @state_machine = MyStateMachine.new
    
    @counter = FrameCounter.new
    
    @history = History.new(@batches, @counter)
    
    @transport = TimelineTransport.new(@counter, @state_machine, @history)
    # ^ methods = [:play, :pause, :seek, :reset]
    
    
    # 
    # lights and cameras
    # 
    @camera = ViewportCamera.new
    @lights = LightsCollection.new
    
    # NOTE: serialization of lights / camera is handled in Core#setup
    
    
    
    
    # TODO: serialize lights and load on startup
    
    
    
    # TODO: one more RubyOF::FloatPixels for the ghosts
    # TODO: one more RubyOF::Texture to render the ghosts
    
    # TODO: should allow re-scanning of the geom texture directory when the World dynamically reloads during runtime. That way, you can start up the engine with a blank canvas, but dynamicallly add things to blender and have them appear in the game, without having to restart the game.
    # ^ not sure if this is still needed. this note brought over from old world.rb
    @crash_detected = false
  end
  
  def setup
    @batches.setup()
    
    @space.setup()
    
    @state_machine.setup do |s|
      s.define_states(
        States::Initial.new(      @state_machine),
        States::GeneratingNew.new(@state_machine, @counter, @history),
        States::ReplayingOld.new( @state_machine, @counter, @transport, @history),
        States::Finished.new(     @state_machine, @counter, @transport, @history)
      )
      
      s.initial_state States::Initial
      
      s.define_transitions do |p|
        p.on_transition :any_other => States::Finished do |ipc|
          puts "finished --> (send message to blender)"
          
          ipc.send_to_blender({
            'type' => 'loopback_finished',
            'history.length' => @counter.max+1
          })
        end
        
        p.on_transition States::GeneratingNew => States::ReplayingOld do |ipc|
          # should cover both pausing and pulling the read head back
          
          ipc.send_to_blender({
            'type' => 'loopback_paused_new',
            'history.length'      => @counter.max+1,
            'history.frame_index' => @counter.to_i
          })
        end
        
        p.on_transition :any => States::ReplayingOld do |ipc|
          if @crash_detected
            @crash_detected = false
          end
        end
      end
    end
  end
  
  def update(ipc, &block)
    # Trigger state transitions as necessary
    @state_machine.update(ipc)
    
    # Update the entities in the world to the next frame,
    # either by executing the code in the block,
    # or loading frames from the history buffer
    # (depending on the current state of the state machine).
    if @transport.playing?
      @state_machine.next_frame(ipc, &block)
      # ^ updates batch[:entity_data][:pixels] and batch[:entity_cache]
      #   ( state machine will decide whether to move 
      #     from pixels -> cache OR cache -> pixels   )
      #   
      #   See History#snapshot and History#load for data flow,
      #   and States::GeneratingNew and States::ReplayingOld for control flow.
    end
    
    # Move entity data to GPU for rendering:
    # move from batch[:entity_data][:pixels] to batch[:entity_data][:texture]
    # ( pixels -> texture )
    @batches.each do |b|
      b[:entity_data][:texture].load_data b[:entity_data][:pixels]
    end
  end
  
  # How does the block executed in GeneratingNew get reset?
  # The block is saved by wrapping in a Fiber.
  # That Fiber is stored in GeneratingNew.
  # When entering GeneratingNew, the Fibers are always set to nil.
  # This allows for new Fibers to be created, and a new block to be bound.
  # See notes in GeneratingNew#on_enter for details.
  
  # How is this triggered during #on_reload_code ?
  # this is supposed to be trigged by History#branch, but not sure...
  
  # TODO: make sure that code can be dynamically reloaded while time is progressing. I tried testing this with the mainline code, and it actually seems kinda buggy. it is possible this was never implemented correctly.
  
  
  # 
  # callbacks that link up to the live coding system
  # 
  
  # callback from live_code.rb
  def on_reload_code(ipc)
    puts "#{@counter.to_s.rjust(4, '0')} code reloaded"
    
    ipc.send_to_blender({
      'type' => 'loopback_reset',
      'history.length'      => @counter.max+1,
      'history.frame_index' => @counter.to_i
    })
    
    @history.branch
    
  end
  
  # callback from live_code.rb
  def on_crash(ipc)
    puts "world: on crash"
    
    # if @counter >= 0
      ipc.send_to_blender({
        'type' => 'loopback_reset',
        'history.length'      => @counter.max+1,
        'history.frame_index' => @counter.to_i
      })
      
      @counter.jmp(@counter.to_i - 1)
      @transport.seek(ipc, @counter.to_i)
    # end
    
    @transport.pause(ipc) # can't move forward any more - can only seek
    
    # puts "set crash flag"
    @crash_detected = true
  end
  
  # Send signal back to Core#update_while_crashed
  # notifying that the crash has been resolved via time travel.
  # 
  # ( the actual resetting of this variable happens
  #   in a state machine callback, defined in World#setup )
  def crash_resolved?
    return !@crash_detected
  end
  
  
  
  
  
  # 
  # callbacks that link up to BlenderSync
  # 
  
  def_delegators :@batches,
    :on_full_export,
    :on_entity_moved,
    :on_entity_created,
    :on_entity_created_with_new_mesh,
    :on_mesh_edited,
    :on_material_edited,
    :on_gc
  
  
  # 
  # serialization
  # 
  # (may not actually need these)
  
  def save
    
  end
  
  def load
    
  end
  
  # 
  # ui code
  # 
  
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
    @batches.each_with_index do |b, i|
      layer_name = b.name
      cache = b[:entity_cache]
      names = b[:names]
      
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
      
      
      
      b[:entity_data][:texture].tap do |texture|
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
      
      
      b[:mesh_data][:textures][:positions].tap do |texture|
        width = [texture.width, 400].min # cap maximum texture width
        x = 970-40
        y = (68+texture.height-20)+i*(189-70)+20
        texture.draw_wh(x,y,0, width, -texture.height)
      end
      
      
      
      texture = b[:mesh_data][:textures][:positions]
      px = texture.width*texture.height
      x = px*channels_per_px*bytes_per_channel / 1000.0
      
      texture = b[:mesh_data][:textures][:normals]
      px = texture.width*texture.height
      y = px*channels_per_px*bytes_per_channel / 1000.0
      
      texture = b[:entity_data][:texture]
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
  
  
end



# TODO: consider creating new 'batches' collection class, to prevent other code from adding elements to the @batches array - should be read-only from most parts of the codebase
class RenderBatchContainer
  def initialize(world, geometry_texture_directory:nil, buffer_length:3600)
    @world = world
    
    @geom_data_dir = geometry_texture_directory
    @buffer_length = buffer_length
    @batches = Array.new
  end
  
  # 
  # mimic parts of the Array interface
  # 
  def each() # &block
    return enum_for(:each) unless block_given?
    
    @batches.each do |b|
      yield b
    end
  end
  
  include Enumerable
  
  def zip(list)
    return @batches.zip(list)
  end
  
  
  # 
  # custom interface for this collection
  # 
  
  def setup
    # allocate 1 RenderBatch object for each texture set
    # that has already been exported from Blender
    # and now currently lives on the disk
    @batches = 
      batch_names_on_disk(@geom_data_dir)
      .collect do |name|
        RenderBatch.new(@geom_data_dir, name)
      end
    
    # load the data from the disk, allocating memory as needed
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.mesh.disk_to_pixels
        x.mesh.pixels_to_texture
        
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.json.disk_to_hash
        
        x.mesh.pixels_to_geometry
      end
      
      # pixels (entity) -> history buffer
      # (not saving the entity data in the buffer, but allocating a buffer)
      b[:entity_history].setup(
        buffer_length: @buffer_length,
        frame_width:   b[:entity_data][:pixels].width,
        frame_height:  b[:entity_data][:pixels].height
      )
    end
  end
  
  # Question:
  # How are the batches reloaded?
  # If I export different batches from blender, or update an existing batch
  # the files need to be reloaded in the engine.
  # Where in the codebase does that actually happen?
  # 
  # in the mainline file,
  # BlenderSync#update_geometry_data
  # -> World#load_json_data
  # -> World#load_entity_texture
  # -> World#load_mesh_textures
  # which then calls methods on VertexAnimationTextureSet
  # 
  # That load logic only handles reloading textures that are already defined.
  # It recieves a name of a file that was updated,
  # so it needs to match that against a batch to figure out what to reload.
  # But because of that, the side-effect is that it can't load a completely
  # new batch. At least, I don't think it should be able to.
  # 
  # What about deleting a batch?
  # How would that work?
  # When we delete entities, we match against a list of known entities.
  # Can I easily get a list of known batches with the current structure,
  # or do I need to export more data?
  
  
  # update existing batches
  # and create new batches as necessary
  def on_full_export(ipc, texture_dir, collection_name)
    batch_names = batch_names_on_disk(@geom_data_dir)
    new_names = Set.new(batch_names) - Set.new(@batches.collect{|x| x.name})
    
    # update 
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.mesh.disk_to_pixels
        x.mesh.pixels_to_texture
        
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.json.disk_to_hash
        
        x.mesh.pixels_to_geometry
      end
      
      # pixels (entity) -> history buffer
      # (not saving the entity data in the buffer, but allocating a buffer)
      b[:entity_history].setup(
        buffer_length: @buffer_length,
        frame_width:   b[:entity_data][:pixels].width,
        frame_height:  b[:entity_data][:pixels].height
      )
    end
    
    
    # create new
    
    
    @history.branch
  end
  
  
  
  
  
  # all texture sets have been exported from scratch
  def on_clean_build(ipc, texture_dir, collection_name)
    @geom_data_dir = texture_dir
    self.setup()
  end
  
  # create one new texture set
  def on_texture_set_created(ipc, texture_dir, collection_name)
    RenderBatch.new(@geom_data_dir, name).tap do |b|
      batch_dsl(b) do |x|
        x.json.disk_to_hash
        
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.mesh.disk_to_pixels
        x.mesh.pixels_to_texture
        
        x.mesh.pixels_to_geometry
      end
      
      # pixels (entity) -> history buffer
      # (not saving the entity data in the buffer, but allocating a buffer)
      b[:entity_history].setup(
        buffer_length: @buffer_length,
        frame_width:   b[:entity_data][:pixels].width,
        frame_height:  b[:entity_data][:pixels].height
      )
      
      @batches << b
    end
    
    
    @history.branch
  end
  
  # delete one existing texture set
  def on_texture_set_deleted(ipc, texture_dir, collection_name)
    @batches.delete_if{|b| b.name == collection_name }
    
    # NOTE: this may cause errors if the current code in the update block depends on the entities that are being deleted
    # NOTE: this also deletes a chunk of history that was associated with that texture set
    
    # (maybe we should push the system back to t=0, as so much of the initial state has changed?)
    
    @history.branch
  end
  
  
  # Question: initial state, or state over time?
  def on_entity_moved(ipc, texture_dir, collection_name)
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.entity.disk_to_pixels
        # x.entity.pixels_to_texture
        # x.entity.pixels_to_cache
      end
    end
    
    
    
    @history.branch
  end
  
  # (not hooked up yet)
  def on_entity_deleted(ipc, texture_dir, collection_name)
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.json.disk_to_hash
        
        # x.mesh.pixels_to_geometry
      end
      
      # b[:entity_history].setup(
      #   buffer_length: @buffer_length,
      #   frame_width:   b[:entity_data][:pixels].width,
      #   frame_height:  b[:entity_data][:pixels].height
      # )
    end
    
    
    
    @history.branch
  end
  
  def on_entity_created(ipc, texture_dir, collection_name)
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.json.disk_to_hash
        
        # x.mesh.pixels_to_geometry
      end
      
      # b[:entity_history].setup(
      #   buffer_length: @buffer_length,
      #   frame_width:   b[:entity_data][:pixels].width,
      #   frame_height:  b[:entity_data][:pixels].height
      # )
    end
    
    
    
    @history.branch
  end
  
  def on_entity_created_with_new_mesh(ipc, texture_dir, collection_name)
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.mesh.disk_to_pixels
        x.mesh.pixels_to_texture
        
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.json.disk_to_hash
        
        # x.mesh.pixels_to_geometry
      end
      
      # b[:entity_history].setup(
      #   buffer_length: @buffer_length,
      #   frame_width:   b[:entity_data][:pixels].width,
      #   frame_height:  b[:entity_data][:pixels].height
      # )
    end
    
    
    
    @history.branch
  end
  
  # note - can't just create new mesh, would have to create a new entity too
  
  # (for now) mesh only effects apperance; should not change history
  # (later when we have animations: may want to branch state based on animation frame, like checking for active frames during an attack animation)
  def on_mesh_edited(ipc, texture_dir, collection_name)
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.mesh.disk_to_pixels
        x.mesh.pixels_to_texture        
      end
    end
    
    @history.branch
  end
  
  # update material data (in entity texture) as well as material names (in json)
  # (for now, material only effects apperance; editingshould not change history)
  def on_material_edited(ipc, texture_dir, collection_name)
    @batches.each do |b|
      batch_dsl(b) do |x|
        x.entity.disk_to_pixels
        x.entity.pixels_to_texture
        x.entity.pixels_to_cache
        
        x.json.disk_to_hash
      end
    end
    
    # @history.branch
  end
  
  # this seems to function on all batches,
  # rather than on a single target batch
  def on_gc(ipc, texture_dir, collection_name)
    
    
    @history.branch
  end
  
  
  # if message['json_file_path'] || message['entity_tex_path']
  #   @world.space.update
  # end
  # TODO: query some hash of queries over time, to figure out if the changes to geometry would have effected spatial queries (see "current issues" notes for details)
  
  private
  
  def batch_names_on_disk(directory)
    directory.children
    .select{ |file| file.basename.to_s.end_with? ".cache.json" }
    .collect do |file|
      # p file
      file.basename.to_s.split('.').first # => name
    end
  end
  
  
  def batch_dsl(batch)
    yield DSL_Helper.new(@geom_data_dir, batch)
  end
  
  class DSL_Helper
    attr_reader :json, :entity, :mesh
    
    def initialize(geom_data_dir, batch)
      args = [
        batch,
        geom_data_dir/"#{batch.name}.cache.json",
        geom_data_dir/"#{batch.name}.position.exr",
        geom_data_dir/"#{batch.name}.normal.exr",
        geom_data_dir/"#{batch.name}.entity.exr"
      ]
      
      @json   = JsonDSL.new(*args)
      @entity = EntityDSL.new(*args)
      @mesh   = MeshDSL.new(*args)
    end
    
    class InnerDSL
      def initialize(b,j,p,n,e)
        @batch = b
        @json_file_path    = j
        @position_tex_path = p
        @normal_tex_path   = n
        @entity_tex_path   = e
      end
    end
    
    # json names API
    class JsonDSL < InnerDSL
      def disk_to_hash
        @batch.load_json_data(@json_file_path)
        return self
      end
    end
    
    # entity texture API
    class EntityDSL < InnerDSL
      # disk -> pixels (entity)
      def disk_to_pixels
        @batch.load_entity_pixels(@entity_tex_path)
        return self
      end
      
      # pixels -> texture (entity)
      def pixels_to_texture
        @batch[:entity_data][:texture].load_data @batch[:entity_data][:pixels]
        return self
      end
      
      # pixels -> cache
      def pixels_to_cache
        @batch[:entity_cache].load @batch[:entity_data][:pixels]
        return self
      end
      
      # cache -> pixels
      def cache_to_pixels
        @batch[:entity_cache].update @batch[:entity_data][:pixels]
        return self
      end
    end
    
    class MeshDSL < InnerDSL
      # disk -> pixels (mesh)
      def disk_to_pixels
        @batch.load_mesh_pixels(@position_tex_path, @normal_tex_path)
        return self
      end
      
      # pixels -> texture (mesh)
      def pixels_to_texture
        [
          [
            @batch[:mesh_data][:textures][:positions],
            @batch[:mesh_data][:pixels][:positions]
          ],
          [
            @batch[:mesh_data][:textures][:normals],
            @batch[:mesh_data][:pixels][:normals]
          ]
        ].each do |texture, pixels|
          texture.load_data pixels
        end
        
        return self
      end
      
      # pixels (mesh) -> geometry
      def pixels_to_geometry
        # NOTE: mesh data dimensions could change on load, but BatchGeometry assumes that the number of verts / triangles in the mesh is constant
        vertex_count = @batch[:mesh_data][:pixels][:positions].width.to_i
        @batch[:geometry].generate vertex_count
        
        return self
      end
    end
    
  end
  
end

  # NOTE: BlenderSync triggers @world.space.update when either json file or entity texture is reloaded
  # ^ currently commented out, so this isn't actually happening

# if the textures are reloaded, then you need to update the entity cache too





















# 
# lights / camera
# 

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
  
  include Enumerable
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
      }.flatten(1).collect do |name, position|
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
    p entity_list
    
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









# 
# 
# Backend - transport entity data to GPU, across all timepoints in history
# 
# 


# based on VertexAnimationTextureSet
# Only manages render data (storage and serialization).
# 
# Does not perform rendering (see OIT_RenderPipeline instead)
# Does not update entity data (see RenderEntityManager instead)
# Does not move data from cache -> pixels -> texture (see World#update instead)
class RenderBatch
  include RubyOF::Graphics
  
  attr_reader :name
  
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
    
    [
      @storage[:mesh_data][:textures][:positions],
      @storage[:mesh_data][:textures][:normals],
      @storage[:entity_data][:texture]
    ].each do |texture|
      texture.disableMipmap() # resets min mag filter
      
      texture.wrap_mode(:vertical   => :clamp_to_edge,
                        :horizontal => :clamp_to_edge)
      
      texture.filter_mode(:min => :nearest, :mag => :nearest)
    end
    
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
  
  # load data from disk -> pixels
  def load_entity_pixels(entity_tex_path)
    [
      [ entity_tex_path,
        @storage[:entity_data][:pixels] ],
    ].each do |path_to_file, pixels|
      ofLoadImage(pixels, path_to_file.to_s)
      
      # y axis is flipped relative to Blender???
      # openframeworks uses 0,0 top left, y+ down
      # blender uses 0,0 bottom left, y+ up
      pixels.flip_vertical
      
      # puts pixels.color_at(0,2)
    end
  end
  
  # position and normals will always be updated in tandem
  # load data from disk -> pixels
  def load_mesh_pixels(position_tex_path, normal_tex_path)
    [
      [ position_tex_path,
        @storage[:mesh_data][:pixels][:positions] ],
      [ normal_tex_path,
        @storage[:mesh_data][:pixels][:normals] ]
    ].each do |path_to_file, pixels|
      ofLoadImage(pixels, path_to_file.to_s)
      
      # y axis is flipped relative to Blender???
      # openframeworks uses 0,0 top left, y+ down
      # blender uses 0,0 bottom left, y+ up
      pixels.flip_vertical
      
      # puts pixels.color_at(0,2)
    end
  end
  
  # ASSUME: pixels and texture are the same dimensions, as they correspond to CPU and GPU representations of the same data
  
  # show an abbreviated version of the data inside the batch, as the entire thing would be many pages long
  def inspect
    "#<#{self.class}:object_id=#{self.object_id} @name=#{@name}>"
  end
  
  class TextureJsonCache
    def initialize
      @json = nil
    end
    
    def load(json_filepath)
      unless File.exist? json_filepath
        # TODO: raises execption after export, but if you restart the game engine everything is fine. need to debug that.
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
    def initialize
      @mesh = nil
    end
    
    def generate(vertex_count)
      @mesh = create_mesh(vertex_count)
    end
    
    def draw_instanced(instance_count)
      @mesh.draw_instanced(instance_count)
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








# Control timeline transport (move back and forward in time)
# In standard operation, these methods are controlled via the blender timeline.
class TimelineTransport
  def initialize(frame_counter, state_machine, history)
    @state_machine = state_machine
    @counter = frame_counter
    @history = history
    
    
    @frame = 0
    @play_or_pause = :paused
  end
  
  def paused?
    return @play_or_pause == :paused
  end
  
  def playing?
    return @play_or_pause == :playing
  end
  
  # if playing, pause forward playback
  # else, do nothing
  def pause(ipc)
    @play_or_pause = :paused
    
    
    if @state_machine.current_state == States::ReplayingOld
      ipc.send_to_blender({
        'type' => 'loopback_paused_old',
        'history.length'      => @counter.max+1,
        'history.frame_index' => @counter.to_i
      })
    end
  end
  
  # if paused, run forward
  # 'running' has different behavior depending on the currently active state
  # may generate new data from code,
  # or may replay saved data from history buffer
  def play(ipc)
    @play_or_pause = :playing
    
    
    if @state_machine.current_state == States::Finished
      ipc.send_to_blender({
        'type' => 'loopback_play+finished',
        'history.length' => @counter.max+1
      })
    end
  end
  
  # instantly move to desired frame number
  # (moving frame-by-frame in blender is implemented in terms of #seek)
  def seek(ipc, frame_number)
    puts "Transport - seek: #{frame_number} [#{@state_machine.current_state}]"
    @state_machine.seek(ipc, frame_number)
    
    # ipc.send_to_blender message
  end
  
  # The blender python extension can send a reset command to the game engine.
  # When that happens, we process it here.
  def reset(ipc)
    puts "loopback reset"
    
    if @state_machine.current_state == States::ReplayingOld
      # For now, just replace the curret timeline with the alt one.
      # In future commits, we can refine this system to use multiple
      # timelines, with UI to compress timelines or switch between them.
      
      @history.branch
      
      ipc.send_to_blender({
        'type' => 'loopback_reset',
        'history.length'      => @counter.max+1,
        'history.frame_index' => @counter.to_i
      })
      
    else
      puts "(reset else)"
    end
  end
  
  def current_frame
    return @counter.to_i
  end
  
  def history_length
    return @counter.max+1
  end
  
  def time_traveling?
    return @state_machine.current_state == States::ReplayingOld
  end
  
  def current_state
    return @state_machine.current_state
  end
  
end



# High-level interface for saving / loading state to HistoryBuffer.
# Allows for saving across all batches simultaneously.
# 
# NOTE: Do not split read / write API, as generating new state requires both.
class History
  def initialize(batches, frame_counter)
    @batches = batches
    @counter = frame_counter
  end
  
  # # create buffer of a certain size
  # def setup
  #   # NO-OP - done in RenderBatch
  # end
  
  # save current frame to buffer
  def snapshot
    @batches.each do |b|
      b[:entity_cache].update b[:entity_data][:pixels]
      b[:entity_history][@counter.to_i] << b[:entity_data][:pixels]
    end
  end
  
  # load current frame from buffer
  def load
    @batches.each do |b|
      b[:entity_history][@counter.to_i] >> b[:entity_data][:pixels]
      b[:entity_cache].load b[:entity_data][:pixels]
    end
  end
  
  # # delete arbitrary frame from buffer
  # def delete(frame_index)
  #   @batches.each do |b|
  #     b[:entity_history][frame_index].delete
  #   end
  # end
  
  # create a new timeline by erasing part of the history buffer
  # (more performant than initializing a whole new buffer)
  def branch
    # invalidate all states after the current frame
    @batches.each do |b|
      ((@counter.to_i+1)..(b[:entity_history].length-1)).each do |i|
        b[:entity_history][i].delete
      end
    end
    # reset the max frame value
    @counter.clip
  end
end


# TODO: stop forward execution if trying to generate new state past the end of the history buffer





# something like a program counter (pc) in assembly
# but that keeps track of the current frame (like in an animation or movie)
# 
# Using 3-letter names to evoke assembly language.
# Ruby also has precedent for using terse names for technical things
# (e.g. to_s)
class FrameCounter
  def initialize
    @value = 0
    @max = 0
  end
  
  # increment the counter
  def inc
    @value += 1
    
    if @value > @max
      @max = @value
    end
    
    return self
  end
  
  # set the frame counter
  # (in assembly, rather than set pc directly, is it set via branch instruction)
  def jmp(i)
    @value = i
    
    return self
  end
  
  # Return the maximum value the counter has reached this run.
  # This is needed to find the index of the last valid frame.
  def max
    return @max
  end
  
  # limit maximum frame to the current value
  def clip
    @max = @value
    
    return self
  end
  
  # when is the maximum value reset?
    # in the main code branch
    # when the code is dynamically reloaded
    # then 
    
    # History::Outer#reload_code -> 
    #   Context#branch_history -> 
    #     HistoryModel#branch
    #       new_history.max_i = frame_index
  
  # what happens if frame index > end of buffer?
  # does it depend on the state?
  # how would that happen?
  # If the buffer's max_i shrinks, doesn't the frame index need to change too?
  # 
  # I think in the main code, history only branches while time traveling.
  # As such, index < end of buffer is also implicitly enforced.
  # Might be possible to get weird behavior if you reload while time is progressing.
  
  
  # TODO: how do you get this value out though? how do you use it?
  # the easiest way to adopt ruby's typecast API, and convert to integer
  
  def to_i
    return @value
  end
  
  def to_s
    return @value.to_s
  end
  
  # also need to define integer-style comparison operators
  # because comparison with numerical values is the main reason to cast to int
  
  include Comparable
  def <=>(other)
    return @value <=> other
  end
end











# abstract definition of state machine structure
# + update     triggers state transitions
# + next       delegate to current state (see 'States' module below)
class MyStateMachine
  # TODO: remove use of state_machine library in live_code.rb, and then rename this class to StateMachine
  
  extend Forwardable
  
  def initialize()
    
  end
  
  def setup(&block)
    helper = StateDefinitionHelper.new(TempStorage.new)
    
    block.call helper
    
    helper.data.tap do |d|
      @states         = d.states
      @transitions    = d.transitions # [prev_state, next_state, Proc]
      
      @previous_state = nil
      @current_state  = d.initial_state
    end
    
  end
  
  # update internal state and fire state transition callbacks
  def update(ipc)
    match(@previous_state, @current_state, transition_args:[ipc])
  end
  
  def_delegators :@current_state,
    :next_frame,
    :seek
  # TODO: Implement custom delegation using method_missing, so that the methods to be delegated can be specified on setup. Should extend the DSL with this extra functionality. That way, the state machine can become a fully reusable component.
  
  
  # trigger transition to the specified state
  def transition_to(new_state_klass)
    if not state_defined? new_state_klass
      raise "ERROR: #{new_state_klass} is not one of the available states declared using #define_states. Valid states are: #{@states.map{|x| x.class}.inspect}"
    end
    
    new_state = find_state(new_state_klass)
    
    puts "transition: #{@current_state.class} -> #{new_state.class}"
    
    new_state.on_enter()
    @previous_state = @current_state
    @current_state = new_state
  end
  
  # returns class of current state (so we know the type of state we're in)
  # rather than the state object (external editing of internal state is bad)
  def current_state
    return @current_state.class
  end
  
  
  
  class StateDefinitionHelper
    attr_accessor :data
    
    def initialize(data)
      @data = data
    end
    
    def define_states(*args)
      # ASSUME: all arguments should be objects that implement the desired semantics of a state machine state. not exactly sure what that means rigorously, so can't perform error checking.
      
      @data.states = args
    end
    
    def initial_state(state_class)
      if @data.states.empty?
        raise "ERROR: Must first declare all possible states using #define_states. Then, you can specify one of those states to be the initial state, by providing the class of that state object."
      end
      
      unless @data.state_defined? state_class
        raise "ERROR: #{state_class.inspect} is not one of the available states declared using #define_states. Valid states are: #{ @data.states.map{|x| x.class} }"
      end
      
      @data.initial_state = @data.find_state(state_class)
    end
    
    def define_transitions(&block)
      helper = PatternHelper.new(@data)
      block.call helper
      # ^ sets @data.transitions directly
    end
  end
  
  class PatternHelper
    def initialize(data)
      @data = data
    end
    
    # States::StateOne => States::StateTwo do ...
    def on_transition(pair={}, &block)
      prev_state_id = pair.keys.first
      next_state_id = pair.values.first
      
      [prev_state_id, next_state_id].each do |state_class|
        unless(state_class == :any || 
               state_class == :any_other ||
               @data.state_defined?(state_class)
        )
          raise "ERROR: State transition was not defined correctly. Given '#{state_class.to_s}', but expected either one of the states declared using #define_states, or the symbols :any or :any_other, which specify sets of states. Defined states are: #{ @data.states.map{|x| x.class}.inspect }"
        end
      end
      
      @data.transitions << [ prev_state_id, next_state_id, block ]
    end
  end
  
  # temporarily store data in this class while state machine is being declared
  class TempStorage
    attr_accessor :states, :transitions, :initial_state
    
    def initialize
      @states = []
      @transitions = []
      @initial_state = nil
    end
    
    # returns true if @states contains an object of the specified class
    def state_defined?(state_class)
      return find_state(state_class) != nil
    end
    
    # return the first state object which is a subclass of the given class
    def find_state(state_class)
      return @states.find{|x| x.is_a? state_class }
    end
  end
  
  
  
  private
  
  def match(p,n, transition_args:[])
    @transitions.each do |prev_state_id, next_state_id, proc|
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
  
  # returns true if @states contains an object of the specified class
  def state_defined?(state_class)
    return find_state(state_class) != nil
  end
  
  # return the first state object which is a subclass of the given class
  def find_state(state_class)
    return @states.find{|x| x.is_a? state_class }
  end
  
end

     
# states used by state machine defined below
# ---
# should we generate new state from code or replay old state from the buffer?
# that depends on the current system state, so let's use a state machine.
# + next       advance the system forward by 1 frame
# + seek       jump to an arbitrary frame
module States
  class Initial
    # initialized once when state machine is setup
    def initialize(state_machine)
      @state_machine = state_machine
    end
    
    # called every time we enter this state
    def on_enter
      
    end
    
    # step forward one frame
    # (name taken from Enumerator#next, which functions similarly)
    def next_frame(ipc, &block)
      @state_machine.transition_to GeneratingNew
    end
    
    # jump to arbitrary frame
    def seek(ipc, frame_number)
      # NO-OP
    end
  end
  
  class GeneratingNew
    # initialized once when state machine is setup
    def initialize(state_machine, frame_counter, history)
      @state_machine = state_machine
      @counter = frame_counter
      @history = history
      
      @f1 = nil
      @f2 = nil
    end
    
    # called every time we enter this state
    def on_enter
      puts "#{@counter.to_s.rjust(4, '0')} start generating new"
      
      @f1 = nil
      @f2 = nil
      
      # p @f1
      
      # Must reset frame index before updating GeneratingNew.
      # Both when entering for the first time, and on re-entry from time travel,
      # need to reset the frame index.
      # 
      # When entering for the first time from Initial, clearly t == 0.
      # 
      # Additoinally, when re-entering GeneratingNew state, it will attempt to
      # fast-forward the Fiber, skipping over frames already rendered,
      # until it reaches the end of the history buffer.
      # There is currently no better way to "resume" code execution.
      # In order to do this, the frame index must be reset to 0 before entry.
      @counter.jmp 0
    end
    
    # step forward one frame
    def next_frame(ipc, &block)
      @f2 ||= Fiber.new do
        # This Fiber wraps the block so we can resume where we left off
        # after Helper pauses execution
        
        # the block used here specifies the entire update logic
        # (broken into individual frames by SnapshotHelper)
        helper = SnapshotHelper.new(@counter, @history)
        block.call(helper)
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
    def seek(ipc, frame_number)
      @state_machine.transition_to ReplayingOld
      @state_machine.seek(ipc, frame_number)
    end
    
    
    
    class SnapshotHelper
      def initialize(frame_counter, history)
        @counter = frame_counter
        @history = history
      end
      
      # wrap generation of one new frame
      # may execute the given block to generate new state, or not
      def frame(&block)
        if @counter < @counter.max
          # resuming
          # (skip this frame)
          
          # All frames up to the desired resume point will execute in one update
          # because there is no Fiber.yield in this branch.
          
          # Can't just jump in the buffer, because we need to advance the Fiber.
          # BUT we may be able to optimize to just loading the last old state
          # before we need to generate new states.
          
          @counter.inc
          
          puts "#{@counter.to_s.rjust(4, '0')} resuming"
          
          @history.load
          
        else # [@counter.max, inf]
          # actually generating new state
          @history.snapshot
          
          # p [@counter.to_i, @counter.max]
          # puts "history length: #{@counter.max+1}"
          
          @counter.inc
          
          frame_str = @counter.to_s.rjust(4, '0')
          src_file, src_line = block.source_location
          
          file_str = src_file.gsub(/#{GEM_ROOT}/, "[GEM_ROOT]")
          
          puts "#{frame_str} new state  #{file_str}, line #{src_line} "
          
          # p block
          # puts "--------------------------------"
          # p block.source_location
          block.call()
          # puts "--------------------------------"
          
          Fiber.yield
        end
      end
    end
    
  end
  
  class ReplayingOld
    # initialized once when state machine is setup
    def initialize(state_machine, frame_counter, transport, history)
      @state_machine = state_machine
      @counter = frame_counter
      @transport = transport
      @history = history
    end
    
    # called every time we enter this state
    def on_enter
      
    end
    
    # step forward one frame
    def next_frame(ipc, &block)
      if @counter >= @counter.max
        # ran past the end of saved history
        # must retun to generating new data from the code
        
        @state_machine.transition_to GeneratingNew
        @state_machine.next_frame(ipc, &block)
        
      else # @counter < @counter.max
        # otherwise, just load the pre-generated state from the buffer
        
        @counter.inc
        @history.load
        
        # stay in state ReplayingOld
      end
    end
    
    # jump to arbitrary frame
    def seek(ipc, frame_number)
      # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
      
      if frame_number.between?(0, @counter.max) # [0, len-1]
        # if range of history buffer, move to that frame
        
        @counter.jmp frame_number
        @history.load
        
        puts "#{@counter.to_s.rjust(4, '0')} old seek"
        
        # stay in state ReplayingOld
        
      elsif frame_number > @counter.max
        # if outside range of history buffer, snap to final frame
        
        # delegate to state :generating_new
        @counter.jmp @counter.max
        @history.load
        
        puts "#{@counter.to_s.rjust(4, '0')} old seek"
        
        @transport.pause(ipc)
        
        # stay in state ReplayingOld
        
      else # frame_number < 0
        raise "ERROR: Tried to seek to negative frame => (#{frame_number})"
      end
      # TODO: Blender frames can be negative. should handle that case too.
          
    end
  end
  
  class Finished
    # initialized once when state machine is setup
    def initialize(state_machine, frame_counter, transport, history)
      @state_machine = state_machine
      @counter = frame_counter
      @transport = transport
      @history = history
    end
    
    # called every time we enter this state
    def on_enter
      puts "#{@counter.to_s.rjust(4, '0')} initial"
    end
    
    # step forward one frame
    def next_frame(ipc, &block)
      # instead of advancing the frame, or altering state,
      # just pause execution again
      @transport.pause(ipc)
    end
    
    # jump to arbitrary frame
    def seek(ipc, frame_number)
      puts "States::Finished - seek #{frame_number} / #{@counter.max}"
      if frame_number >= @counter.max
        # NO-OP
      else
        puts "seek"
        @state_machine.transition_to ReplayingOld
        @state_machine.seek(ipc, frame_number)
        
      end
    end
  end
end





# Stores the data for time traveling
# 
# Data structure for a sequence of images over time.
# It does not know anything about the specifics
# of the vertext animation texture system.
# 
# writing API:
#   state = RubyOF::FloatPixels.new
#   buffer = HistoryBuffer.new
#   buffer[i] << state
# reading API
#   state = RubyOF::FloatPixels.new
#   buffer = HistoryBuffer.new
#   buffer[i] >> state
class HistoryBuffer
  # ASSUME: data is stored in RubyOF::FloatPixels
  
  # TODO: use named arguments, because the positions are extremely arbitrary
  def initialize(mom=nil, slice_range=nil)
    if mom
      @max_num_frames = mom.max_num_frames
      self.setup(buffer_length: mom.length,
                 frame_width:   mom.frame_width,
                 frame_height:  mom.frame_height)
      slice_range.each do |i|
        @buffer[i] << mom.buffer[i]
      end
    else
      @max_num_frames = 0
      @buffer = []
      @valid = []
    end
      
      # (I know this needs to save entity data, but it may not need to save mesh data. It depends on whether or not all animation frames can fit in VRAM at the same time or not.)
  end
  
  def setup(buffer_length:3600, frame_width:9, frame_height:100)
    puts "[ #{self.class} ]  setup "
    
    @max_num_frames = buffer_length
    
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
  
  # get helper from buffer at a particular index
  # returns a reference to RubyOF::FloatPixels
  def [](frame_index)
    raise IndexError, "Index should be a non-negative integer. (Given #{frame_index.inspect} instead.)" if frame_index.nil?
    
    raise "Memory not allocated. Please call #{self.class}#setup first" if self.length == 0
    
    raise IndexError, "Index out of bounds. Expected index in the range of 0..#{self.length-1}, but recieved #{frame_index}." unless frame_index.between?(0, self.length-1)
    
    
    return HistoryBufferHelper.new(@buffer, @valid, frame_width, frame_height, frame_index)
  end
  
  # HistoryBuffer can't store the index of the last valid frame any more
  # the new API has only one interface for reading and writing.
  # In this way, it is unclear when to increment the 'max' value.
  
  
  # image buffers are guaranteed to be the right size,
  # (as long as the buffer is allocated)
  # because of setup()
  
  class HistoryBufferHelper
    def initialize(buffer, valid, frame_width, frame_height, i)
      @buffer = buffer
      @valid = valid
      @i = i
      
      @width  = frame_width
      @height = frame_height
    end
    
    # move data from other to buffer
    # (write to the buffer)
    def <<(other)
      raise "Can only store RubyOF::FloatPixels data in HistoryBuffer" unless other.is_a? RubyOF::FloatPixels
      
      other_size  = [other.width, other.height]
      buffer_size = [@width, @height]
      raise "Dimensions of provided frame data do not match the size of frames in the buffer. Provided: #{other_size.inspect}; Buffer size: #{buffer_size.inspect}" unless other_size == buffer_size
      
      @buffer[@i].copy_from other
      @valid[@i] = true
    end
    
    # move data from buffer into other
    # (read from the buffer)
    def >>(other)
      # can only read data out of buffer
      # if the data at that index is valid
      # (otherwise, it could just be garbage)
      
      raise "Attempted to read garbage state. State at frame #{@i} was either never saved, or has since been deleted." unless @valid[@i]
      
      other.copy_from @buffer[@i]
    end
    
    # delete the data the index tracked by this helper object
    def delete
      @valid[@i] = false
    end
  end
  
  
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
