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
        @outer.state = :drive 
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
        
      end
      
      def frame(&block)
        
      end
      
      def play
        @outer.state = :drive 
      end
      
      def pause
        
      end
      
      def step_forward
        
      end
      
      def step_back
        
      end
      
      def reverse
        @outer.instance_eval do
          
          @f1 = Fiber.new do
            while @executing_frame > 0 do
              @executing_frame -= 1
              
              p [@executing_frame, @history.length-1]
              
              state = @history[@executing_frame]
              @context.load_state state
              
              Fiber.yield
            end
            
          end
          
          
          self.state = :reverse
        end
      end
    end
    
    
    
    class Drive < State
      def update
        fiber_dead = false
        @outer.instance_eval do
          
          if @f1.alive?
            @f1.resume()
          else
            fiber_dead = true
          end
          
        end
        
        if fiber_dead
          @outer.state = :finished
        end
      end
      
      def frame(&block)
        @outer.instance_eval do
          
          
          state = @context.snapshot_gamestate
          @history[@executing_frame] = state
          
          p [@executing_frame, @history.length-1]
          # puts "history length: #{@history.length}"
          
          @executing_frame += 1
          
          block.call
          
          Fiber.yield
          
        end
      end
      
      def play
        
      end
      
      def pause
        @outer.state = :paused
      end
      
      def step_forward
        
      end
      
      def step_back
        
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
          
          @f1 = Fiber.new do
            while @executing_frame > 0 do
              @executing_frame -= 1
              
              p [@executing_frame, @history.length-1]
              
              state = @history[@executing_frame]
              @context.load_state state
              
              Fiber.yield
            end
            
          end
          
          
          self.state = :reverse
        end
      end
    end
    
    
    class Reverse < State
      def update
        fiber_dead = false
        @outer.instance_eval do
          
          if @f1.alive?
            @f1.resume() 
          else
            fiber_dead = true
          end
          
        end
        
        if fiber_dead
          @outer.state = :park
        end
        
      end
      
      def frame(&block)
        
      end
      
      def play
        
      end
      
      def pause
        @outer.state = :park
      end
      
      def step_forward
        
      end
      
      def step_back
        
      end
      
      def reverse
        @outer.instance_eval do
          
          
          
          
        end
      end
    end
    
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
      if state1 == current_state_name && state2 == new_state_name
        puts ">> edge callback: #{state1} -> #{state2}"
        callback.call()
      end
    end
    
    # trigger state change
    @state = @all_states[new_state_name]
    
    puts "state = #{new_state_name}"
  end
  
  
  def initialize(context)
    @context = context
    
    
    @edge_callbacks = Array.new
    
    
    # 
    # Populate a hash called @all_states
    # with one instance of each class in the States module.
    # The expected format is similar to this:
    # 
    # { :park => States::Park.new(self) }
    # 
    p self.class::States.constants
    
    @all_states = Hash.new
    
    states_module = self.class::States
    states_module.constants.each do |const_sym|
      klass = states_module.const_get const_sym
      @all_states[const_sym.to_s.downcase.to_sym] = klass.new(self)
    end
    
    
    
    
    
    
    
    @executing_frame = 0
    @target_frame = 20
    
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
    
    
    
    self.state = :park
    
    
    after_transition :park, :drive do
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
    
    
  end
  
  extend Forwardable
  def_delegators :@state, :frame, :play, :pause, :reverse
  
  def update
    @state.update
  end
  
  def after_transition(state1, state2, &block)
    @edge_callbacks << [state1, state2, block]
  end
  
  
  # def frame(&block)
  #   # TODO: rather than executing this frame immediately, assign the passed block some frame number, and compare that number to the desired frame of execution. then, the desired frame number can be manually scrubbed back-and-forth in order to control the point of execution
  #     # this needs to be paired with a sytem that has memory of previous states. when old frames are not actively executed, their state should be pulled from this memory. that frame delta can be used to advance the state instead of computing fresh data.
    
  #   # Below is some prototype logic to get the ball rolling
    
  #   if @state != :reverse_cycle
  #     while @paused do
  #       Fiber.yield
        
        
  #       if @take_one_step
  #         @take_one_step = false
  #         break
  #       end
  #     end
      
      
      
  #     p [@executing_frame, @state_history.length]
      
  #     if @state == :forward
  #       iterate_forward(block)
  #     elsif @state == :reverse
  #       iterate_back()
  #     end
      
      
  #     Fiber.yield
      
      
  #   elsif @state == :reverse_cycle
  #     # NO-OP
  #     # (just trying to get back to the right place in the code)
  #     # (don't actually execute anything)
      
  #   else
  #     raise "frame history encountered unexpected state: #{@state}"
  #   end
    
  # end
  
  
  
  # private
  
  # def generate_fibers()
  #   @f2 = Fiber.new do
  #     @context.on_update(self)
  #   end
    
  #   @f1 = Fiber.new do
  #     loop do
  #       # forward cycle
  #       while @f2.alive?
  #         @f2.resume(self)
  #         Fiber.yield
  #       end
        
  #       # hit the end of execution
  #       @paused = true
  #       @state = :neutral
        
  #       puts "start second loop"
  #       # reverse cycle
  #       loop do
  #         # potential to just iterate backwards
  #         if @state == :reverse
  #           p [@executing_frame, @state_history.length]
  #           iterate_back()
            
  #         elsif @state == :forward
  #           resume_forward()
  #           @state = :forward
  #           break # end the reverse cycle
            
  #         elsif @state == :neutral # :neutral
  #           Fiber.yield
            
  #         else
  #           raise "unknown state detected"
            
  #         end
  #       end
        
  #       puts "start new cycle"
        
        
  #       # pause before start of the next cycle
  #       Fiber.yield
  #     end
  #   end
  # end
  
  # def iterate_forward(block)
  #   state = @context.snapshot_gamestate
  #   @state_history[@executing_frame] = state
    
  #   puts "history length: #{@state_history.length}"
    
  #   @executing_frame += 1
    
  #   block.call
  # end
  
  # def iterate_back
  #   puts "iterate back"
    
  #   if @executing_frame > 0
  #     @executing_frame -= 1
      
  #     state = @state_history[@executing_frame]
  #     @context.load_state(state)
        
  #     Fiber.yield
  #   elsif @executing_frame == 0
  #     @state = :neutral
  #   end
  # end
  
  # # you have advanced through some (or perhaps all) code blocks
  # # you now need to resume from some known frame
  # def resume_forward
  #   @f2 = Fiber.new do
  #     @context.on_update(self)
  #   end
    
  #   @target_frame = @executing_frame
  #   @executing_frame = 0
  #   @state = :reverse_cycle
    
  #   puts "executing frame: #{@executing_frame}"
  #   puts "target_frame: #{@target_frame}"
  #   puts "#{@executing_frame} < #{@target_frame}"
    
  #   while @executing_frame < @target_frame
  #     @f2.resume(self)
      
  #     Fiber.yield
  #   end
  # end
  
  
end
