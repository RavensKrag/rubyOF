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
    class Initial < State
      def update
        
      end
      
      def frame(&block)
        
      end
      
      def play
        @outer.state = :generating_new 
      end
      
      def pause
        # NO-OP
        # (already not going anywhere)
      end
      
      def step_forward
        
      end
      
      def step_back
        
      end
      
      def reverse
        
      end
    end
    
    class Paused < State
      def update
        # NO-OP
      end
      
      def frame(&block)
        
      end
      
      def play
        @outer.instance_eval do
          
          if @executing_frame < @history.length-1
            # currently exploring the past
            self.state = :replaying_old
          else
            # currently ready to generate new future data
            self.state = :generating_new
          end
          
        end
      end
      
      def pause
        # NO-OP
        # (already paused - self loop)
      end
      
      def step_forward
        @outer.instance_eval do
          
          puts "step forward #{@executing_frame} -> #{@executing_frame+1} (#{@history.length-1})"
          
          @queued_state = :paused
          if @executing_frame < @history.length-1
            # currently exploring the past
            self.state = :replaying_old
          else
            # currently ready to generate new future data
            self.state = :generating_new
          end
          
        end
      end
      
      def step_back
        @outer.instance_eval do
          
          puts "step back #{@executing_frame} -> #{@executing_frame-1} (#{@history.length-1})"
          @queued_state = :paused
          self.state = :reverse
          
          
        end
      end
      
      def reverse
        @outer.instance_eval do
          
          self.state = :reverse
          
        end
      end
    end
    
    # BUG: go forward, then pause, then go backwards, pause, then forward again
    # Improperly advances through history using code execution right away, instead of replaying some forward state in history and then advancing with code later
    
    # (forward via code execution)
    class Generating_New < State
      def update
        @outer.instance_eval do
          
          if @f1.alive?
            @f1.resume()
          else
            self.state = :finished
          end
          
          # after one iteration via this method, transition to the queued state
          if @queued_state
            self.state = @queued_state
            @queued_state = nil
          end
          
        end
      end
      
      def frame(&block)
        @outer.instance_eval do
          
          if @executing_frame < @history.length
            # resuming
            
            # puts "resuming"
            # (skip this frame)
            @executing_frame += 1
            
          elsif @executing_frame > @history.length
            
          else # @executing_frame > @history.length-1
            # actually generating new state
            
            state = @context.snapshot_gamestate
            @history[@executing_frame] = state
            
            # p [@executing_frame, @history.length-1]
            # puts "history length: #{@history.length}"
            
            @executing_frame += 1
            
            block.call
            
            Fiber.yield
          end
          
        end
      end
      
      def play
        
      end
      
      def pause
        @outer.state = :paused
      end
      
      def step_forward
        # NO-OP
        # (actively running, can't manually step)
        # (if you want to manually step, should first pause)
      end
      
      def step_back
        # NO-OP
        # (actively running, can't manually step)
        # (if you want to manually step, should first pause)
      end
      
      def reverse
        
      end
    end
    
    # (forward via stored history)
    class Replaying_Old < State
      def update
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
          
          # after one iteration via this method, transition to the queued state
          if @queued_state
            self.state = @queued_state
            @queued_state = nil
          end
          
        end
      end
      
      def frame(&block)
        
      end
      
      def play
        
      end
      
      def pause
        @outer.state = :paused
      end
      
      def step_forward
        # NO-OP
        # (actively running, can't manually step)
        # (if you want to manually step, should first pause)
      end
      
      def step_back
        # NO-OP
        # (actively running, can't manually step)
        # (if you want to manually step, should first pause)
      end
      
      def reverse
        
      end
    end
    
    class Finished < State
      def update
        
      end
      
      def frame(&block)
        
      end
      
      def play
        
      end
      
      def pause
        # NO-OP
        # (already not advancing state)
      end
      
      def step_forward
        
      end
      
      def step_back
        
      end
      
      def reverse
        @outer.instance_eval do
          
          self.state = :reverse
          
        end
      end
    end
    
    
    class Reverse < State
      def update
        @outer.instance_eval do
          
          if @f1.alive?
            @f1.resume() 
          else
            self.state = :paused
          end
          
          # after one iteration via this method, transition to the queued state
          if @queued_state
            self.state = @queued_state
            @queued_state = nil
          end
          
        end
      end
      
      def frame(&block)
        
      end
      
      def play
        
      end
      
      def pause
        # must have paused somewhere in the middle. if we hit the beginning of history, then the state would have been set to :initial in #update
        @outer.state = :paused
      end
      
      def step_forward
        # NO-OP
        # (actively running, can't manually step)
        # (if you want to manually step, should first pause)
      end
      
      def step_back
        # NO-OP
        # (actively running, can't manually step)
        # (if you want to manually step, should first pause)
      end
      
      def reverse
        
      end
    end
    
  end
  
  def setup_states()
    @executing_frame = 0
    @target_frame = 20
    
    
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
    
    after_transition :ANY, :reverse do
      @f1 = Fiber.new do
        while @executing_frame > 0 do
          @executing_frame -= 1
          
          # p [@executing_frame, @history.length-1]
          
          state = @history[@executing_frame]
          @context.load_state state
          
          Fiber.yield
        end
      end
    end
    
    
    
  end
  
  
  
  
  
  
  
  def initialize(context)
    @context = context
    
    
    @edge_callbacks = Array.new
    
    
    # 
    # Populate a hash called @all_states
    # with one instance of each class in the States module.
    # The expected format is similar to this:
    # 
    # { :initial => States::initial.new(self) }
    # 
    p self.class::States.constants
    
    @all_states = Hash.new
    
    states_module = self.class::States
    states_module.constants.each do |const_sym|
      klass = states_module.const_get const_sym
      @all_states[const_sym.to_s.downcase.to_sym] = klass.new(self)
    end
    
    
    
    
    
    
    @history = Array.new
    
    # @f2 = Fiber.new do
    #   @context.on_update(self)
    # end
    
    # @f1 = Fiber.new do
    #   # forward cycle
    #   while @f2.alive?
    #     @f2.resume()
    #     Fiber.yield
    #   end
    # end
    
    setup_states()
  end
  
  
  
  
  
  def state=(new_state_name)
    current_state_name = 
      if @state.nil?
        "<null>"
      else
        @state.name
      end
    
    @state = nil # <-- blank this out so you get an error if you try to access the "current" state during a transition
    
    # implement triggers on certain edges
    @edge_callbacks.each do |state1, state2, callback|
      if( (state1 == current_state_name || state1 == :ANY) &&
          (state2 == new_state_name     || state2 == :ANY) )
        puts ">> edge callback: #{state1} -> #{state2}"
        callback.call()
      end
    end
    
    unless @all_states.keys.include? new_state_name
      raise "Invalid state name '#{new_state_name}' for state machine in #{self.class}. Expected one of the following: #{@all_states.keys}" 
    end
    
    # trigger state change
    @state = @all_states[new_state_name]
    
    puts "state = #{new_state_name}"
  end
  
  
  extend Forwardable
  def_delegators :@state, 
    :frame, :play, :pause, :reverse, :step_back, :step_forward
  
  def update
    @state.update
  end
  
  def after_transition(state1, state2, &block)
    @edge_callbacks << [state1, state2, block]
  end
  
  # TODO: rather than executing this frame immediately, assign the passed block some frame number, and compare that number to the desired frame of execution. then, the desired frame number can be manually scrubbed back-and-forth in order to control the point of execution
    # this needs to be paired with a sytem that has memory of previous states. when old frames are not actively executed, their state should be pulled from this memory. that frame delta can be used to advance the state instead of computing fresh data.
  
end
