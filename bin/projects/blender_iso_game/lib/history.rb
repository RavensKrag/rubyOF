module History


class Outer
  attr_accessor :paused
  attr_accessor :frame_index
  
  def initialize
    @history = History::HistoryModel.new
    @frame_index = 0
    
    @context = Context.new(@history) # holds the information
    @state   = States::NullBehavior.new(@context) # holds the behavior
  end
  
  def bind_to_world(world)
    world.bind_history @history
    # |--> HistoryModel#setup()    
  end
  
  def time_traveling?
    return @state.class == States::ReplayingOld
  end
  
  extend Forwardable
  
  def_delegators :@history, 
    :size, :length
  
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
    # set history
    @history = @history.branch @frame_index
    
    # TODO: double-buffer history to reduce memory allocation
      # always have two history buffers available
      # when you branch, just copy the "main" one into the "backup" one
      # then start using the "backup" as the primary, and clear the old main.
      # Not sure how to extend this to n timelines,
      # or if that is even necessary.
    
    return self
  end
  
  def_delegators :@state, 
    :update, :seek, :on_crash
    # (frame-by-frame traversal uses :seek)
  
  def_delegators :@context,
    :play, :pause
  
  def state
    @state.class.name
  end
  
end


class Context
  attr_accessor :f1, :f2
  attr_accessor :history
  
  def initialize(history)
    @history = history
    @state = States::NullBehavior.new(self)
    
    @f1 = nil
    @f2 = nil
    
    @play_or_pause = :paused
  end
  
  # transition after this callback completes and wait for further commands
  def transition_to(new_state_klass)
    new_state = new_state_klass.new(self)
    new_state.on_enter()
    @state = new_state
  end
  
  # transition now, and re-run the last callback in the new state
  def transition_and_rerun(new_state_klass, method_name, *args, **kwargs)
    new_state = new_state_klass.new(self)
    new_state.on_enter()
    new_state.call(method_name, *args, **kwargs)
    @state = new_state
  end
  
  def play
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
      
    else # [@history.length-1, inf]
      # actually generating new state
      @context.history.snapshot_gamestate_at @context.frame_index
      
      # p [@context.frame_index, @history.length-1]
      # puts "history length: #{@history.length}"
      
      @context.frame_index += 1
      
      puts "#{@context.frame_index.to_s.rjust(4, '0')} new state"
      
      # p block
      puts "--------------------------------"
      p block.source_location
      block.call()
      puts "--------------------------------"
      
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

module States
  class State
    def initialize(context)
      @context = context
    end
  end
  
  class NullBehavior < State
    def on_enter
      
    end
    
    def update
      
    end
    
    def seek
      
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
      puts "#{@context.frame_index.to_s.rjust(4, '0')} reset @final_frame"
      
      @context.f1 = nil
      @context.f2 = nil
      
      # p @f1
      @context.frame_index = 0
    end
    
    def update(&block)
      return if @outer.paused?
      
      
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
      
      if frame_number >=0 && frame_number <= @context.final_frame # [0, len-1]
        # if you try to seek to an old frame,
        # delegate to state :replaying_old
        
        @context.transition_and_rerun ReplayingOld, :seek, frame_number   
      else # [len, inf]
        # if you try to seek to a future frame,
        # need to synchronize blender to
        # the last currently available frame instead
        
        # move to end of buffer and transition to Generating_New
        @context.frame_index = @context.final_frame
        
        @history.load_state_at @executing_frame
        
        # TODO: check to see that this branch works correctly. will need to keep state synced between RubyOF and Blender.
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
      if @context.frame_index == @context.final_frame
        puts "#{@context.frame_index.to_s.rjust(4, '0')} replaying_old (update) -> finished"
        puts "#{@context.final_frame}"
        
        @context.transition_to Finished
        
      elsif @context.frame_index < @context.final_frame
        
        @context.frame_index += 1
        
        # p [@context.frame_index, @context.history.length-1]
        puts "#{@context.frame_index.to_s.rjust(4, '0')} old"
        
        @context.history.load_state_at @context.frame_index
      else # @context.frame_index > @context.final_frame
        @context.transition_to GeneratingNew
      end
        
    end
    
    def seek(frame_number)
      # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
      
      if frame_number == @context.final_frame
        @context.frame_index = frame_number
        
        # 
        # print info about transition
        # 
        puts "#{@context.frame_index.to_s.rjust(4, '0')} replaying_old (seek) -> finished"
        puts "#{@context.final_frame}"
        
        # 
        # transition
        # 
        @context.transition_to Finished
        
      elsif frame_number >= 0 && frame_number <= @context.final_frame # [0, len-1]
        # within range of history buffer
        
        @context.frame_index = frame_number
        
        # p [@context.frame_index, @context.history.length-1]
        puts "#{@context.frame_index.to_s.rjust(4, '0')} old"
        
        @context.history.load_state_at @context.frame_index
      else # [len, inf]
        # if outside range of history buffer
        # delegate to state :generating_new
        
        @context.transition_and_rerun GeneratingNew, :seek, frame_number
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
      
      @context.final_frame = @context.frame_index
      
      puts "#{@context.frame_index.to_s.rjust(4, '0')} final frame saved to history"
      
      # ^ used by Finished#seek
      puts "final frame: #{@context.final_frame}"
        
      
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
        @context.transition_and_rerun ReplayingOld, :seek, frame_number
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
  
  # TODO: use named arguments, because the positions are extremely arbitrary
  def initialize(mom=nil)
    if mom
      @max_num_frames = mom.max_num_frames
      self.setup(mom.state[:pixels],
                 mom.state[:texture],
                 mom.state[:cache]
      )
      @buffer.size.times do |i|
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
    new_buffer = @buffer.slice(0..frame_index)
    new_history = self.class.new(new_buffer)
    
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
    raise "Memory not allocated. Please call #allocate first" if self.length == 0
    
    raise IndexError, "Index #{frame_index} outside the bounds of recorded gamestates: 0..#{self.length-1}" unless frame_index >= 0 && frame_index <= self.length-1
    
    @pixels.copy_from @buffer[frame_index]
    @cache.load @pixels
  end
  
  def snapshot_gamestate_at(frame_index)
    raise "Memory not allocated. Please call #allocate first" if self.length == 0
    
    raise IndexError, "Index #{frame_index} outside of array bounds: 0..#{self.max_length-1}" unless frame_index >= 0 && frame_index <= self.max_length-1
    
    
    @cache.update @pixels
    @buffer[frame_index].copy_from @pixels
    
    if frame_index > @max_i
      @max_i = frame_index
    end
    # # TODO: implement this new interface
    # @buffer[frame_index] << @pixels # save data into history buffer
    # @buffer[frame_index] >> @pixels # load data from buffer into another image
    #   # + should I implement this on RubyOF::Pixels for all images?
    #   # + can this be patterned as a general "memory transfer operator" ?
      
    # @pixels << @buffer[frame_index] # load data from buffer into another image
    
    
    
    # TODO: implement a C++ function to copy the image data
      # current code just saves a ruby reference to an existing image,
      # which is not what we want.
      # we want a separate copy of the memory,
      # so that the original @pixels can continue to mutate
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
