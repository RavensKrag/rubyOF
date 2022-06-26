module History


class Outer
  def initialize
    history = History::HistoryModel.new
    
    @context = Context.new(history)
  end
  
  def bind_to_world(world)
    world.bind_history @context.history
    # |--> HistoryModel#setup()
  end
    
  # recieved a message from Core that a crash was detected this frame
  # (called every frame while Core is in the crashed state)
  def crash_detected
    # puts "set crash flag"
    @crash_detected = true
  end
  
  # let Core know if the crash could be resolved via time travel
  def crash_detected?
    return @crash_detected
  end
  
  extend Forwardable
  
  def_delegators :@context, 
    :frame_index, :length, :update, :on_crash
  
  # NOTE: This is to be used for debug printing / UI only. All functionality that meaningfully depends on the state should be delegated to the state via @context. That's the entire point of using the State design pattern.
  def state
    @context.current_state.name.split("::").last
  end
  
  def time_traveling?
    return @context.current_state.class == States::ReplayingOld
  end
  
  
  
  # TODO: consider storing ipc handle on init instead of passing to all of these methods when they are called
  
  
  
  # NOTE: the following methods are like delegates to @context, but also can send messages to Blender via the BlenderSync IPC mechanism
  
  def update(ipc, &block) 
    @patterns ||= StatePatterns.new do |p|
      p.on_transition :any_other => States::Finished do
        puts "finished --> (send message to blender)"
        
        ipc.send_to_blender({
          'type' => 'loopback_finished',
          'history.length' => @context.history.length
        })
      end
      
      
      
      # User story:
        # While the game is executing, I want to drag the bar on the timeline to jump back in time, without explictly entering into time travel mode. I don't want to have to hit the pause button first - I want to just drag, and for the system to simply do the right thing.
      # Current behavior:
        # Normally, when pausing, blender sets the end of the active timeframe to the end of the frame buffer. this happens due to a message that is sent from the engine to the editor. When you drag the timeline when in play mode, while in GeneratingNew state, this change of timeframe does not happen. Thus, the ReplayingOld state can not stop playing at the end of the timeframe as expected.
        # Can't just call @context.pause when seeking in GeneratingNew, because that will not necessarily send the needed message to blender - the message is only sent if Outer#seek(ipc, ...) is called.
      
    end
    
    @patterns.match(
      @context.previous_state.class, @context.current_state.class
    )
    
    @context.previous_state = @context.current_state
    
    
    @context.current_state.update(&block)
  end
  
  def on_reload_code(ipc)
    @patterns = nil
    @context.branch_history
    
    ipc.send({
      'type' => 'loopback_reset',
      'history.length'      => @context.history.length,
      'history.frame_index' => @context.frame_index
    })
  end
  
  def on_reload_data(ipc)
    @context.branch_history
    
    # ipc.send_to_blender message
  end
  
  def reset(ipc)
    puts "loopback reset"
    
    if @context.current_state.class == States::ReplayingOld
      # For now, just replace the curret timeline with the alt one.
      # In future commits, we can refine this system to use multiple
      # timelines, with UI to compress timelines or switch between them.
      
      puts "try to generate a new timeline"
      
      @context.branch_history
      # @context.transition_to States::GeneratingNew
      
      ipc.send_to_blender({
        'type' => 'loopback_reset',
        'history.length'      => @context.history.length,
        'history.frame_index' => @context.frame_index
      })
      
    else
      puts "(reset else)"
    end
  end
  
  def pause(ipc)
    @context.pause
    
    if @context.current_state.class == States::GeneratingNew
      ipc.send_to_blender({
        'type' => 'loopback_paused_new',
        'history.length'      => @context.history.length,
        'history.frame_index' => @context.frame_index
      })
      
    else
      ipc.send_to_blender({
        'type' => 'loopback_paused_old',
        'history.length'      => @context.history.length,
        'history.frame_index' => @context.frame_index
      })
    end
    
  end
  
  def play(ipc)
    @context.play
    
    if @context.current_state.class == States::Finished
      ipc.send_to_blender({
        'type' => 'loopback_play+finished',
        'history.length' => @context.history.length
      })
    end
    
  end
  
  # both frame-by-frame traversal and scrubbing use :seek
  def seek(ipc, time)
    @context.seek(time)
    # ipc.send_to_blender message
  end
end


# Methods on Context are visible to other parts of this internal API,
# but are not visible to external systems, 
# because Outer does not provide external access to Context.
# This is good - it allows Context to hold all private internal state
class Context
  attr_accessor :f1, :f2
  
  attr_reader :history
  attr_accessor :frame_index
  
  attr_accessor :previous_state, :current_state
  
  def initialize(history)
    # Context holds the data
    # @state holds the behavior
    
    @history = history
    
    @current_state = States::Initial.new(self)
    @previous_state = nil
    
    @frame_index = 0
    
    @f1 = nil
    @f2 = nil
    
    @play_or_pause = :paused
    
    @current_state.on_enter
  end
  
  extend Forwardable
  
  def_delegators :@current_state,
    :update, :seek, :on_crash
    
  def_delegators :@history,
    :length
  
  
  # If FrameHistory contains states through time,
  # and replaying those states is "time traveling",
  # then this method creates a new parallel timeline.
  # 
  # Create a copy of the current timeline,
  # but reset part of the state, such that
  # all state from this point forward is invalidated.
  # Thus, that part of the state will be generated anew.
  # (Useful for loading new code)
  def branch_history
    puts "branch history"
    @history = @history.branch @frame_index
    
    # TODO: double-buffer history to reduce memory allocation
      # always have two history buffers available
      # when you branch, just copy the "main" one into the "backup" one
      # then start using the "backup" as the primary, and clear the old main.
      # Not sure how to extend this to n timelines,
      # or if that is even necessary.
    
    return self
  end
  
  
  # transition after this callback completes and wait for further commands
  def transition_to(new_state_klass)
    new_state = new_state_klass.new(self)
    
    puts "transition: #{@current_state.class} -> #{new_state.class}"
    
    new_state.on_enter()
    @previous_state = @current_state
    @current_state = new_state
    
  end
  
  # transition now, and re-run the last callback in the new state
  def transition_and_rerun(state_class, method_name, *args, **kwargs, &block)
    new_state = state_class.new(self)
    
    puts "transition: #{@current_state.class} -> #{new_state.class}"
    puts "   rerun args: #{args.inspect}"
    puts "   rerun kwargs: #{kwargs.inspect}"
    puts "   rerun with block?: #{block.nil?}"
    
    new_state.on_enter()
    new_state.send(method_name, *args, **kwargs)
    @previous_state = @current_state
    @current_state = new_state
    
  end
  
  def play
    puts "> play (#{@current_state.name}) t_current=#{@frame_index} t_final=#{self.final_frame}"
    @play_or_pause = :play
  end
  
  def pause
    @play_or_pause = :paused
  end
  
  def paused?
    return @play_or_pause == :paused
  end
  
  def final_frame
    @history.length-1
  end
end



# match patterns of states and fire appropriate callbacks
# on transitions between states
class StatePatterns
  def initialize() # &block
    helper = Helper.new
    yield helper
    @patterns = helper.patterns
  end
  
  def match(p,n)
    @patterns.each do |pattern, proc|
      prev_state_id, next_state_id = pattern
      
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
        proc.call()
      end
    end
  end
  
  
  class Helper
    attr_reader :patterns
    
    def initialize
      @patterns = Array.new
    end
    
    def on_transition(pair={}, &block)
      prev_state_id = pair.keys.first
      next_state_id = pair.values.first
      
      @patterns << [ [prev_state_id, next_state_id], block ]
    end
  end
end


# Helper object that allows for the definition of different "frames" in Core.
# Passed to each #update
class Snapshot
  def initialize(context)
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
      
      @context.history.load_state_at @context.frame_index
      
    else # [@context.history.length-1, inf]
      # actually generating new state
      @context.history.snapshot_gamestate_at @context.frame_index
      
      # p [@context.frame_index, @context.history.length-1]
      # puts "history length: #{@context.history.length}"
      
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
    # elsif @executing_frame > @context.history.length
    #   # scrubbing in future space
    #   # NO-OP
    #   # (pretty sure I need both this logic and the logic in Finished)
    # else
    #   # initial state??
    #   # not sure what's left
    end
    
  end
end


module States
  class State
    def initialize(context)
      @context = context
    end
    
    def name
      self.class.to_s
    end
  end
  
  class NullBehavior < State
    def on_enter
      
    end
    
    def update(&block)
      
    end
    
    def seek(frame_number)
      
    end
    
    def on_crash
      
    end
  end
  
  class Initial < State
    def on_enter
      puts "#{@context.frame_index.to_s.rjust(4, '0')} initial"
    end
    
    def update(&block)
      if @context.paused?
        # NO-OP
        return
      else
        @context.transition_to GeneratingNew
      end
    end
    
    def seek(frame_number)
      # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
      
      # NO-OP
    end
    
    # needed for crash recovery
    def on_crash
      # nothing to do - we're in the initial state, so no changes get made
      
      # NO-OP
    end
  end
  
  class GeneratingNew < State
    def on_enter
      puts "#{@context.frame_index.to_s.rjust(4, '0')} start generating new"
      
      @context.f1 = nil
      @context.f2 = nil
      
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
      @context.frame_index = 0
    end
    
    def update(&block)
      return if @context.paused?
      
      
      @context.f2 ||= Fiber.new do
        # should create a closure around block variable
        # because it is an instance variable
        block.call(Snapshot.new(@context))
      end
      
      @context.f1 ||= Fiber.new do
        # forward cycle
        while @context.f2.alive?
          @context.f2.resume()
          Fiber.yield
        end
      end
      
      
      if @context.f1.alive?
        @context.f1.resume()
      else
        @context.transition_to Finished
      end
    end
    
    # jump to specified frame number
    # (used for time traveling - stepping and playing)
    def seek(frame_number)
      # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
      
      # any attempt to seek should be seen as a form of time travel
      
      puts "#{@context.frame_index.to_s.rjust(4, '0')} new seek: #{@context.frame_index} -> #{frame_number}"
      
      if frame_number == @context.final_frame + 1
        # NO-OP
        
        # Sometimes you trigger this when you really should be updating.
        # Seems to happen when transitioning from ReplayingOld to GeneratingNew
        # at the boundary of the history buffer.
        
        # Just stub this for now.
        
      else
        # @context.transition_and_rerun ReplayingOld, :seek, frame_number
        @context.transition_to ReplayingOld
        @context.seek(frame_number)
        
      end
        
      
    end
    
    def on_crash
      self.seek(@context.frame_index - 1)
    end
  end
  
  # (forward via shared history)
  class ReplayingOld < State
    def on_enter
      @crash_detected = false
    end
    
    # reverse playback is handled by Blender via #seek - do not need explict reverse playback mode
    def update(&block)
      return if @context.paused?
      
      # NOTE: not in a Fiber
      puts "#{@context.frame_index.to_s.rjust(4, '0')} old update [#{@context.frame_index} / #{@context.history.length-1}]"
      
      if @context.frame_index >= @context.final_frame
        # @context.transition_and_rerun(GeneratingNew, :update, &block)
        @context.transition_to GeneratingNew
        @context.update(&block)
        
      else # @context.frame_index < @context.final_frame
        @context.frame_index += 1
        @context.history.load_state_at @context.frame_index
        
        # stay in state ReplayingOld
      end
        
    end
    
    def seek(frame_number)
      # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
      
      if frame_number.between?(0, @context.final_frame) # [0, len-1]
        # if range of history buffer, move to that frame
        
        @context.frame_index = frame_number
        @context.history.load_state_at @context.frame_index
        
        puts "#{@context.frame_index.to_s.rjust(4, '0')} old seek"
        
        # stay in state ReplayingOld
        
      elsif frame_number > @context.final_frame
        # if outside range of history buffer, snap to final frame
        
        # delegate to state :generating_new
        @context.frame_index = @context.final_frame
        @context.history.load_state_at @context.frame_index
        
        puts "#{@context.frame_index.to_s.rjust(4, '0')} old seek"
        
        @context.pause
        
        # stay in state ReplayingOld
        
      else # frame_number < 0
        raise "ERROR: Tried to seek to negative frame => (#{frame_number})"
      end
      # TODO: Blender frames can be negative. should handle that case too.
          
    end
    
    def on_crash
      self.seek(@context.frame_index - 1)
    end
  end
  
  class Finished < State
    def on_enter
      puts "Finished update"
      
      @context.pause
      
      # The final state has not been saved yet,
      # because states don't get saved when they are created
      # but rather at the beginning of the next state.
      # Thus, the initial state and the final state are special
      # (edge cases / boundary conditions).
      
      @context.history.snapshot_gamestate_at @context.frame_index
      
      puts "#{@context.frame_index.to_s.rjust(4, '0')} final frame saved to history"
      
      # ^ used by Finished#seek
      # puts "final frame: #{@context.final_frame}"
        
      
      # p [@context.frame_index, @context.history.length-1]
      # puts "history length: #{@context.history.length}"
      
      puts "#{@context.frame_index.to_s.rjust(4, '0')} finished"
    end
    
    def update(&block)
      if @context.paused?
        # NO-OP
      else
        # instead of advancing the frame, or altering state,
        # just pause execution again
        @context.pause
      end
    end
    
    def seek(frame_number)
      puts "Finished seek"
      puts "frame_number #{frame_number.inspect}"
      # puts "@final_frame #{@final_frame.inspect}"
      # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
      
      if frame_number >= @context.final_frame
        # NO-OP
      else
        # @context.transition_and_rerun ReplayingOld, :seek, frame_number
        @context.transition_to ReplayingOld
        @context.seek(frame_number)
        
      end
    end
    
    def on_crash
      self.seek(@context.frame_index - 1)
    end
  end
end






















# external API to access history data via @world.history
# control writing / loading data on dynamic entities over time
class HistoryModel
  attr_reader :max_num_frames, :state, :buffer
  attr_accessor :max_i
  
  protected :state
  protected :buffer
  
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
    end
      # @buffer : HistoryBuffer object
      # storage is one big image,
      # but API is like an array of images
      
      # ^ list of frames over time, not just one state
      # should combine with FrameHistory#frame_index to get data on a particular frame
      # (I know this needs to save entity data, but it may not need to save mesh data. It depends on whether or not all animation frames can fit in VRAM at the same time or not.)
    
    
    @max_i = -1
  end
  
  def setup(pixels, texture, cache)
    puts "[ #{self.class} ]  setup "
    
    @max_num_frames = 3600
    
    # retain key data objects for entity state
    @state = {
      :pixels => pixels,
      :texture => texture,
      :cache => cache
    }
    
    # store data
    @buffer = Array.new(@max_num_frames)
    @buffer.size.times do |i|
      pixels = RubyOF::FloatPixels.new
      
      pixels.allocate(@state[:pixels].width, @state[:pixels].height)
      pixels.flip_vertical
      
      @buffer[i] = pixels
    end
  end
  
  def buffer_width
    @buffer.frame_width
  end
  
  def buffer_height
    @buffer.frame_height
  end
  
  def max_length
    return @max_num_frames
  end
  
  def length
    return @max_i + 1
  end
  
  alias :size :length
  
  
  # TODO: think about how you would implement multiple timelines
  def branch(frame_index)
    new_history = self.class.new(self, 0..frame_index)
    
    new_history.max_i = frame_index
    
    return new_history
  end
  
  
  
  # TODO: consider storing the current frame_count here, to have a more natural interface built around #<< / #push
  # (would clean up logic around setting frame data to not be able to set arbitrary frames, but that "cleaner" version might not actually work because of time traveling)
  
  
  # sketch out new update flow
  
  # Each update with either generate new state, or just advance time.
  # If new state was generated, we need to send it to the GPU to see it.
  
  
  
  # image buffers are guaranteed to be the right size,
  # (as long as the buffer is allocated)
  # because of setup()
  def load_state_at(frame_index)
    raise IndexError, "Index should be a non-negative integer. (Given #{frame_index.inspect} instead.)" if frame_index.nil?
    
    raise "Memory not allocated. Please call #{self.class}#setup first" if self.max_length == 0
    
    raise IndexError, "Index #{frame_index} outside the bounds of recorded gamestates: 0..#{self.length-1}" unless frame_index.between?(0, self.length-1)
    
    @state[:pixels].copy_from @buffer[frame_index]
    @state[:cache].load @state[:pixels]
  end
  
  def snapshot_gamestate_at(frame_index)
    raise IndexError, "Index should be a non-negative integer." if frame_index.nil?
    
    raise "Memory not allocated. Please call #{self.class}#setup first" if self.max_length == 0
    
    raise IndexError, "Index #{frame_index} outside of array bounds: 0..#{self.max_length-1}" unless frame_index.between?(0, self.max_length-1)
    
    
    @state[:cache].update @state[:pixels]
    @buffer[frame_index].copy_from @state[:pixels]
    
    if frame_index > @max_i
      @max_i = frame_index
    end
    # # TODO: implement this new interface
    # @buffer[frame_index] << @state[:pixels] # save data into history buffer
    # @buffer[frame_index] >> @state[:pixels] # load data from buffer into another image
    #   # + should I implement this on RubyOF::Pixels for all images?
    #   # + can this be patterned as a general "memory transfer operator" ?
      
    # @state[:pixels] << @buffer[frame_index] # load data from buffer into another image
    
    
    
    # TODO: implement a C++ function to copy the image data
      # current code just saves a ruby reference to an existing image,
      # which is not what we want.
      # we want a separate copy of the memory,
      # so that the original @state[:pixels] can continue to mutate
      # without distorting what's in the history buffer
    # (actually, current ruby array is fast enough)
    # (just having Pixels#copy_from is fast enough for now)
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




end
