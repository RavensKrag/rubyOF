# NOTE: prototype file was being loaded by the dynamic reload system before I wanted it to effect the main codebase. why was this being loaded?

# TODO: test history / time travel systems


# TODO: implement high-level interface for when one blender object is exported as mulitple entity / mesh pairs. in other words, you have one logical render entity, but the low-level system has many entities and many meshes that need to be managed.

load LIB_DIR/'render_batches.rb' # RenderBatch, RenderBatchCollection
load LIB_DIR/'render_entities.rb' # RenderEntity, MeshSprite, etc
load LIB_DIR/'space.rb' # Space, PhysicsEntity, etc 

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
        States::Initial.new(      @state_machine, @history),
        States::GeneratingNew.new(@state_machine, @counter, @history),
        States::ReplayingOld.new( @state_machine, @counter, @transport, @history),
        States::Finished.new(     @state_machine, @counter, @transport, @history)
      )
      
      s.initial_state States::Initial
      
      
      s.define_transitions do |p|
        p.on_transition :any => States::ReplayingOld do |ipc|
          if @crash_detected
            @crash_detected = false
          end
        end
      end
      
    end
    
  end
  
  def update(ipc, &block)
    # ( state transitions are fired automatically by
    #   MyStateMachine#transition_to - no need for an #update method  )
    
    # Update the entities in the world to the next frame,
    # either by executing the code in the block,
    # or loading frames from the history buffer
    # (depending on the current state of the state machine).
    if @transport.playing?
      @state_machine.current_state.next_frame(ipc, &block)
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


# 
# 
# Backend - transport entity data to GPU, across all timepoints in history
# 
# 

# Control timeline transport (move back and forward in time)
# In standard operation, these methods are controlled via the blender timeline.
class TimelineTransport
  def initialize(frame_counter, state_machine, history)
    @state_machine = state_machine
    @counter = frame_counter
    @history = history
    
    
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
    puts "== pause"
    
    @play_or_pause = :paused
    @state_machine.current_state.on_pause(ipc)
    
    puts "====="
  end
  
  # if paused, run forward
  # 'running' has different behavior depending on the currently active state
  # may generate new data from code,
  # or may replay saved data from history buffer
  def play(ipc)
    puts "== play"
    
    @play_or_pause = :playing
    @state_machine.current_state.on_play(ipc)
    
    puts "====="
  end
  
  # instantly move to desired frame number
  # (moving frame-by-frame in blender is implemented in terms of #seek)
  def seek(ipc, frame_number)
    puts "Transport - seek: #{frame_number} [#{@state_machine.current_state}]"
    @state_machine.current_state.seek(ipc, frame_number)
    
    # ipc.send_to_blender message
  end
  
  # The blender python extension can send a reset command to the game engine.
  # When that happens, we process it here.
  def reset(ipc)
    # For now, just replace the curret timeline with the alt one.
    # In future commits, we can refine this system to use multiple
    # timelines, with UI to compress timelines or switch between them.
    
    self.pause(ipc)
    @history.branch
    
    ipc.send_to_blender({
      'type' => 'loopback_reset',
      'history.length'      => @counter.max+1,
      'history.frame_index' => @counter.to_i
    })
  end
  
  def current_frame
    return @counter.to_i
  end
  
  def final_frame
    return @counter.max
  end
  
  def time_traveling?
    return @state_machine.current_state.is_a? States::ReplayingOld
  end
  
  def current_state
    return @state_machine.current_state
  end
  
end



# states used by state machine defined below
# ---
# should we generate new state from code or replay old state from the buffer?
# that depends on the current system state, so let's use a state machine.
# + next_frame   advance the system forward by 1 frame
# + seek         jump to an arbitrary frame
module States
  class Initial
    # initialized once when state machine is setup
    def initialize(state_machine, history)
      @state_machine = state_machine
      @history = history
    end
    
    # called every time we enter this state
    def on_enter
      puts "#{@counter.to_s.rjust(4, '0')} initial state"
      
      @history.snapshot
    end
    
    # step forward one frame
    # (name taken from Enumerator#next, which functions similarly)
    def next_frame(ipc, &block)
      @state_machine.transition_to GeneratingNew, ipc
      @state_machine.current_state.next_frame(ipc, &block)
    end
    
    def on_play(ipc)
      # NO-OP
    end
    
    def on_pause(ipc)
      # NO-OP
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
    def on_enter(ipc)
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
        @state_machine.transition_to Finished, ipc
      end
    end
    
    def on_play(ipc)
      
    end
    
    def on_pause(ipc)
      ipc.send_to_blender({
        'type' => 'loopback_paused_new',
        'history.length'      => @counter.max+1,
        'history.frame_index' => @counter.to_i
      })
      
      # @history.snapshot
      @state_machine.transition_to States::ReplayingOld, ipc
    end
    
    # jump to arbitrary frame
    def seek(ipc, frame_number)
      # TODO: consider saving state here before seeking backwards
      puts "States::Finished - seek #{frame_number} / #{@counter.max}"
      
      ipc.send_to_blender({
        'type' => 'loopback_record_scratch',
        'history.length'      => @counter.max+1,
        'history.frame_index' => @counter.to_i
      })
      
      # @history.snapshot
      @state_machine.transition_to ReplayingOld, ipc
      @state_machine.current_state.seek(ipc, frame_number)
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
          
          puts "#{@counter.to_s.rjust(4, '0')} resuming [#{@counter.to_i} / #{@counter.max}]"
          
          @history.load
          
        else # [@counter.max, inf]
          # actually generating new state
          
          @counter.inc
          
          frame_str = @counter.to_s.rjust(4, '0')
          src_file, src_line = block.source_location
          file_str = src_file.gsub(/#{GEM_ROOT}/, "[GEM_ROOT]")
          
          puts "#{frame_str} new state  #{file_str}, line #{src_line} "
          
            block.call()
          
          @history.snapshot
          
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
    def on_enter(ipc)
      puts "#{@counter.to_s.rjust(4, '0')} replaying old"
    end
    
    # step forward one frame
    def next_frame(ipc, &block)
      if @counter >= @counter.max
        # ran past the end of saved history
        # must retun to generating new data from the code
        
        @state_machine.transition_to GeneratingNew, ipc
        @state_machine.current_state.next_frame(ipc, &block)
        
      else # @counter < @counter.max
        # otherwise, just load the pre-generated state from the buffer
        
        @counter.inc
        @history.load
        
        # stay in state ReplayingOld
      end
    end
    
    def on_play(ipc)
      
    end
    
    def on_pause(ipc)
      ipc.send_to_blender({
        'type' => 'loopback_paused_old',
        'history.length'      => @counter.max+1,
        'history.frame_index' => @counter.to_i
      })
      
      # remain in ReplayingOld - no transition
    end
    
    # jump to arbitrary frame
    def seek(ipc, frame_number)
      # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
      
      if frame_number.between?(0, @counter.max) # [0, len-1]
        # if range of history buffer, move to that frame
        
        @counter.jmp frame_number
        @history.load
        
        puts "#{@counter.to_s.rjust(4, '0')} replaying old: seek"
        
        # stay in state ReplayingOld
        
      elsif frame_number > @counter.max
        # if outside range of history buffer, snap to final frame
        
        # delegate to state :generating_new
        @counter.jmp @counter.max
        @history.load
        
        puts "#{@counter.to_s.rjust(4, '0')} replaying old: seek - end of timeline"
        
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
    def on_enter(ipc)
      puts "#{@counter.to_s.rjust(4, '0')} finished"
      
      # @history.snapshot
      
      ipc.send_to_blender({
        'type' => 'loopback_finished',
        'history.length' => @counter.max+1
      })
    end
    
    # step forward one frame
    def next_frame(ipc, &block)
      # instead of advancing the frame, or altering state,
      # just pause execution again
      @transport.pause(ipc)
    end
    
    def on_play(ipc)
      ipc.send_to_blender({
        'type' => 'loopback_play+finished',
        'history.length' => @counter.max+1
      })
    end
    
    def on_pause(ipc)
      puts "(blender triggered pause after code finished)"
    end
    
    # jump to arbitrary frame
    def seek(ipc, frame_number)
      puts "States::Finished - seek #{frame_number} / #{@counter.max}"
      if frame_number >= @counter.max
        # NO-OP
      else
        puts "seek"
        @state_machine.transition_to ReplayingOld, ipc
        @state_machine.current_state.seek(ipc, frame_number)
        
      end
    end
  end
end




















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
    # should reset when code is dynamically reloaded,
    # and the history branches
  
  # what happens if frame index > end of buffer?
  # does it depend on the state?
  # how would that happen?
  # If the buffer's max_i shrinks, doesn't the frame index need to change too?
  # 
  # I think in the main code, history only branches while time traveling.
  # As such, index < end of buffer is also implicitly enforced.
  # Might be possible to get weird behavior if you reload while time is progressing.
  
  
  # how do you get this value out though? how do you use it?
  # the easiest way to adopt ruby's typecast API, and convert to integer
  
  def to_i
    return @value
  end
  
  def to_s
    return @value.to_s
  end
  
  # Comparison with numerical values is the main reason to cast to int.
  # Thus, also define integer-style comparison operators
  # so that you don't have to manually cast as often.
  
  include Comparable
  def <=>(other)
    return @value <=> other
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
      
      unless @valid[@i]
        msg = [
          "Attempted to read garbage state. State at frame #{@i} was either never saved, or has since been deleted.",
          "#{@valid.collect{|x| x ? "1" : "0" }.join('') }"
        ]
        raise msg.join("\n")
      end
      
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


