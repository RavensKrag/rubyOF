class FrameHistory
  class State
    def initialize(context)
      @outer = context
    end
    
    def name
      self.class.name.split("::").last.downcase.to_sym
    end
  end
  
  class AnyState
    
  end
  
  
  module States
    # (first frame that can be generated by code. no state generated yet)
    class Initial < State
      def update
        return if @outer.paused
        
        @outer.state = :generating_new
      end
      
      def frame(&block)
        
      end
      
      def play
        @outer.paused = false
      end
      
      def pause
        @outer.paused = true
      end
      
      def seek(frame_number)
        # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
        @outer.instance_eval do
          
        end
      end
      
      # needed for crash recovery
      def step_back
        self.seek(@outer.frame_index - 1)
      end
    end
    
    # BUG: go forward, then pause, then go backwards, pause, then forward again
    # Improperly advances through history using code execution right away, instead of replaying some forward state in history and then advancing with code later
    
    # (forward via code execution)
    class Generating_New < State
      def update
        return if @outer.paused
        
        @outer.instance_eval do
          
          if @f1.alive?
            @f1.resume()
          else
            self.state = :finished
          end
          
        end
      end
      
      def frame(&block)
        @outer.instance_eval do
          
          # TODO: make sure that on resuming forward progress after code reload, many frames are advanced in one RubyOF frame. if you don't do that, then Blender timeline and RubyOF state will desync.
          if @executing_frame < @history.length-1
            # resuming
            
            # if manually stepping forward, we'll be able to see the transition
            # but otherwise, this transition will be silent
            # (keeps logs clean unless you really need the info)
            if @queued_state
              puts "resuming"
            end
            
            # (skip this frame)
            
            @executing_frame += 1
            
          elsif @executing_frame == @history.length
            # actually generating new state
            
            state = @context.snapshot_gamestate
            @history[@executing_frame] = state
            
            # p [@executing_frame, @history.length-1]
            # puts "history length: #{@history.length}"
            
            @executing_frame += 1
            
            block.call
            
            Fiber.yield
          elsif @executing_frame > @history.length
            # scrubbing in future space
            # NO-OP
            # (pretty sure I need both this logic and the logic in Finished)
          else
            # initial state??
            # not sure what's left
          end
          
        end
      end
      
      def play
        @outer.paused = false
      end
      
      def pause
        @outer.paused = true
      end
      
      # jump to specified frame number
      # (used for time traveling - stepping and playing)
      def seek(frame_number)
        # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
        @outer.instance_eval do
          if frame_number >=0 && frame_number <= @history.length-1 # [0, len-1]
            # if you try to seek to an old frame,
            # delegate to state :replaying_old
            
            self.state = :replaying_old            
          else # [len, inf]
            # if you try to seek to a future frame,
            # need to synchronize blender to
            # the last currently available frame instead
            
            # move to end of buffer and transition to Generating_New
            @executing_frame = @history.length-1
            # ^ if you remove the -1, there is a nil in the buffer which causes a crash
            
            state = @history[@executing_frame]
            @context.load_state state
            
            # TODO: check to see that this branch works correctly. will need to keep state synced between RubyOF and Blender.
          end
          
          
          
        end
      end
      
      # needed for crash recovery
      def step_back
        self.seek(@outer.frame_index - 1)
      end
    end
    
    # (forward via stored history)
    class Replaying_Old < State
      # reverse playback is handled by Blender via #seek - do not need explict reverse playback mode
      def update
        return if @outer.paused
        
        @outer.instance_eval do
          
          # NOTE: not in a Fiber
          if @executing_frame < @history.length-1
            @executing_frame += 1
            
            # p [@executing_frame, @history.length-1]
            
            state = @history[@executing_frame]
            @context.load_state state
          else
            self.state = :generating_new
          end
          
        end
      end
      
      def frame(&block)
        # NO-OP
        # (blank because #update does not use a Fiber)
      end
      
      # enable forward playback.
      def play
        @outer.paused = false
      end
      
      def pause
        @outer.paused = true
      end
      
      # jump to specified frame number
      # (used for time traveling - stepping and playing)
      def seek(frame_number)
        # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
        @outer.instance_eval do
          
          if frame_number >= 0 && frame_number <= @history.length-1 # [0, len-1]
            # within range of history buffer
            @executing_frame = frame_number
            
            # p [@executing_frame, @history.length-1]
            
            state = @history[@executing_frame]
            @context.load_state state
          else # [len, inf]
            # if outside range of history buffer
            # delegate to state :generating_new
            
            self.state = :generating_new
          end
          # TODO: Blender frames can be negative. should handle that case too.
          
        end
      end
      
      # needed for crash recovery
      def step_back
        self.seek(@outer.frame_index - 1)
      end
    end
    
    # (final frame that can be generated by code)
    class Finished < State
      def update
        puts "Finished update"
        @final_frame = @outer.length-1
        p @final_frame
      end
      
      def frame(&block)
        
      end
      
      # enable forward playback.
      def play
        # @outer.paused = false
      end
      
      def pause
        # @outer.paused = true
      end
      
      # jump to specified frame number
      # (used for time traveling - stepping and playing)
      def seek(frame_number)
        puts "Finished seek"
        puts "frame_number #{frame_number.inspect}"
        puts "@final_frame #{@final_frame.inspect}"
        # TODO: make sure Blender timeline when scrubbing etc does not move past the end of the available time, otherwise the state here will become desynced with Blender's timeline
        
        if frame_number >= @final_frame
          # NO-OP
        else
          @outer.instance_eval do
            self.state = :replaying_old
          end
        end
      end
      
      # needed for crash recovery
      def step_back
        self.seek(@outer.frame_index - 1)
      end
    end
    
    
  end
  
  
  def frame_index
    return @executing_frame
  end
  
  def time_traveling?
    return @executing_frame < @history.length-1
  end
  
  def size
    @history.size
  end
  
  def length
    @history.length
  end
  
  
  attr_accessor :paused
  
  def setup_states()
    @executing_frame = 0
    # @target_frame = 20
    
    @paused = true
    
    self.state = :initial
    
    
    after_transition :ANY, :generating_new do
      @f2 = Fiber.new do
        @context.on_update(self)
      end
      
      @f1 = Fiber.new do
        # forward cycle
        while @f2.alive?
          @f2.resume()
          Fiber.yield
        end
      end
      
      # p @f1
      @executing_frame = 0
    end
    
    after_transition :ANY, :replaying_old do
      # puts "reset crash flag"
      @crash_detected = false
      
    end
    
    
    
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
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  # --- WARNING ---
  # This particular way of using class variables
  # makes it difficult to dynamically reload 
  # this class properly. What happens to this class
  # after dynamic reload (with respect to defining
  # new states) is undefined.
  # 
  # If you need to redefine the state machine,
  # you will need to restart the entire application.
  # 
  # (could fix this by defining some #on_reload callback)
  def initialize(context)
    @context = context
    
    
    @@edge_callbacks ||= Array.new
    
    
    # 
    # Populate a hash called @@all_states
    # with one instance of each class in the States module.
    # The expected format is similar to this:
    # 
    # { :initial => States::initial.new(self) }
    # 
    p self.class::States.constants
    
    @@all_states ||= Hash.new
    
    states_module = self.class::States
    states_module.constants.each do |const_sym|
      klass = states_module.const_get const_sym
      @@all_states[const_sym.to_s.downcase.to_sym] = klass.new(self)
    end
    
    
    @history = Array.new
    
    setup_states()
  end
  
  
  
  def state
    @state.name
  end
  
  # transition to new state
  def state=(new_state_name)
    current_state_name = 
      if @state.nil?
        "<null>"
      else
        @state.name
      end
    
    # @state = nil # <-- blank this out so you get an error if you try to access the "current" state during a transition
    
    
    unless @@all_states.keys.include? new_state_name
      raise "Invalid state name '#{new_state_name}' for state machine in #{self.class}. Expected one of the following: #{@@all_states.keys}" 
    end
    
    # trigger state change
    @state = @@all_states[new_state_name]
    
    
    # implement triggers on certain edges
    @@edge_callbacks.each do |state1, state2, callback|
      if( (state1 == current_state_name || state1 == :ANY) &&
          (state2 == new_state_name     || state2 == :ANY) )
        puts ">> edge callback: #{state1} -> #{state2}"
        callback.call()
      end
    end
    
    
    puts "state = #{new_state_name}"
  end
  
  
  # extend Forwardable
  # def_delegators :@state, 
  #   :frame, :play, :pause, :reverse, :step_back, :step_forward
  
  
  # Delegate some methods to the active state.
  # However, if state transition happens while calling,
  # change state immediately and re-call the method
  # in the new state.
  [:update, :frame, :play, :pause, :seek, :step_back].each do |sym|
    define_method(sym) do |*args, **kwargs, &block|
      old_state_name = @state.name
      
      @state.send(sym, *args, **kwargs, &block)
      
      if old_state_name != @state.name
        @state.send(sym, *args, **kwargs, &block)
      end
      # TODO: maybe this should loop?
      
    end
  end
  
  
  def after_transition(state1, state2, &block)
    @@edge_callbacks << [state1, state2, block]
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
    # most state in FrameHistory is either shared (class variables)
    # or immutable (symbols). Each snapshot saved to @history can 
    # also be viewed as immutable, but the entire Array is mutable.
    
    # raise "Execution must be paused before creating a new timeline using #branch_history" unless @state.name == :paused
    
    # new_timeline = self.dup # shallow copy
    # # https://stackoverflow.com/questions/10183370/whats-the-difference-between-rubys-dup-and-clone-methods
    
    # # change @history variable
    # new_timeline.instance_eval do
    #   # shallow copy, as elements are considered immutable
    #   new_history = @history.dup
      
    #   # snip off part of the history
    #   new_history = new_history[0..@executing_frame]
      
    #   # set history
    #   @history = new_history
    # end
    
    
    # return new_timeline
    
    
    new_history = @history[0..@executing_frame]
      
    # set history
    @history = new_history
    
    return self
  end
  
  
  # TODO: rather than executing this frame immediately, assign the passed block some frame number, and compare that number to the desired frame of execution. then, the desired frame number can be manually scrubbed back-and-forth in order to control the point of execution
    # this needs to be paired with a sytem that has memory of previous states. when old frames are not actively executed, their state should be pulled from this memory. that frame delta can be used to advance the state instead of computing fresh data.
  
end
