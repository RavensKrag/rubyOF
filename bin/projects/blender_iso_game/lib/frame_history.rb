class FrameHistory
  def initialize(context)
    @context = context
    
    # TODO: how do I write code that looks sorta like this, but also allows going back? I'm willing to mark the end of a frame, but not give each frame an explict "number", at least not in the block defined here.
    
    generate_fibers()
    
    
    @executing_frame = 0
    @target_frame = 20
    
    @state_history = Array.new
    
    @paused = true
    @take_one_step = false
    @state = :forward
  end
  
  def update
    
    if @f1.alive?
      @f1.resume(self) 
    end
    
  end
  
  
  def frame(&block)
    # TODO: rather than executing this frame immediately, assign the passed block some frame number, and compare that number to the desired frame of execution. then, the desired frame number can be manually scrubbed back-and-forth in order to control the point of execution
      # this needs to be paired with a sytem that has memory of previous states. when old frames are not actively executed, their state should be pulled from this memory. that frame delta can be used to advance the state instead of computing fresh data.
    
    # Below is some prototype logic to get the ball rolling
    
    if @state != :reverse_cycle
      while @paused do
        Fiber.yield
        
        
        if @take_one_step
          @take_one_step = false
          break
        end
      end
      
      
      
      p [@executing_frame, @state_history.length]
      
      if @state == :forward
        iterate_forward(block)
      elsif @state == :reverse
        iterate_back()
      end
      
      
      Fiber.yield
      
      
    elsif @state == :reverse_cycle
      # NO-OP
      # (just trying to get back to the right place in the code)
      # (don't actually execute anything)
      
    else
      raise "frame history encountered unexpected state: #{@state}"
    end
    
  end
  
  def step_forward
    if @paused
      @take_one_step = true
      @state = :forward
    end
  end
  
  def step_back
    if @paused
      @take_one_step = true
      @state = :reverse
    end
  end
  
  def pause
    @paused = true
  end
  
  def play
    @paused = false
    @state = :forward
  end
  
  def reverse
    @paused = false
    @state = :reverse
  end
  
  
  private
  
  def generate_fibers()
    @f2 = Fiber.new do
      @context.on_update(self)
    end
    
    @f1 = Fiber.new do
      loop do
        # forward cycle
        while @f2.alive?
          @f2.resume(self)
          Fiber.yield
        end
        
        # hit the end of execution
        @paused = true
        @state = :neutral
        
        puts "start second loop"
        # reverse cycle
        loop do
          # potential to just iterate backwards
          if @state == :reverse
            p [@executing_frame, @state_history.length]
            iterate_back()
          elsif @state == :forward
            resume_forward()
            break # end the reverse cycle
          else # :neutral
            Fiber.yield
          end
        end
        
        puts "start new cycle"
        @state = :forward
        
        # pause before start of the next cycle
        Fiber.yield
      end
    end
  end
  
  def iterate_forward(block)
    state = @context.snapshot_gamestate
    @state_history[@executing_frame] = state
    
    puts "history length: #{@state_history.length}"
    
    @executing_frame += 1
    
    block.call
  end
  
  def iterate_back
    puts "iterate back"
    
    if @executing_frame > 0
      @executing_frame -= 1
      
      state = @state_history[@executing_frame]
      @context.load_state(state)
        
      Fiber.yield
    elsif @executing_frame == 0
      @state = :neutral
    end
  end
  
  # you have advanced through some (or perhaps all) code blocks
  # you now need to resume from some known frame
  def resume_forward
    @f2 = Fiber.new do
      @context.on_update(self)
    end
    
    @target_frame = @executing_frame
    @executing_frame = 0
    @state = :reverse_cycle
    
    puts "executing frame: #{@executing_frame}"
    puts "target_frame: #{@target_frame}"
    puts "#{@executing_frame} < #{@target_frame}"
    
    while @executing_frame < @target_frame
      @f2.resume(self)
      
      Fiber.yield
    end
  end
  
  
end
