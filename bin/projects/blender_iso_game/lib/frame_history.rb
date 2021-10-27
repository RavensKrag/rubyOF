class FrameHistory
  def initialize(context)
    @context = context
    
    # TODO: how do I write code that looks sorta like this, but also allows going back? I'm willing to mark the end of a frame, but not give each frame an explict "number", at least not in the block defined here.
    @f2 = Fiber.new do
      @context.on_update(self)
    end
    
    @f1 = Fiber.new do
      while @f2.alive?
        @f2.resume(self)
        Fiber.yield
      end
    end
    
    
    @executing_frame = 0
    @target_frame = 20
    
    @state_history = Array.new
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
    
    p [@executing_frame, @target_frame]
    
    state = @context.snapshot_gamestate
    @state_history[@executing_frame] = state
    
    @executing_frame += 1
    
    block.call
    
    # if (50..100).include? @executing_frame
    #   # either execute code to generate the frame
    # else
    #   # or load the data from history
    # end
    
    
    Fiber.yield
    
    
    
    
    
    # # first frame that the on_update gets called is frame 1
    # # frame 0 is just the initial state
    
    # # should always snapshot BEFORE the block call happens
    
    # @executing_frame = 0
    
    # state = @context.snapshot_gamestate
    # @state_history[@executing_frame] = state # frame 0
    
    # @executing_frame += 1
    
    # block.call                # frame 1
    
    # state = @context.snapshot_gamestate
    # @state_history[1] = state # frame 1
    
    # @executing_frame += 1
    
    # block.call                # frame 2
    
    # state = @context.snapshot_gamestate
    # @state_history[2] = state # frame 2
  end
  
  
end
