require 'state_machine'

class Controller
  attr_reader :i
  
  def initialize(main_code, space, user_input)
    super()
    
    @live_code  = main_code     # code env with live reloading
    @core_space = space         # space containing main entities
    @user_input = user_input    # raw user input data (drives sequences)
    
    
    @i = 0
  end
  
  # paused / running
  # pause in the 
  
  
  state_machine :execution_state, :initial => :paused do
    # replaying saved states
    state :replaying do
      
      def update
        
      end
      
      def draw
        
      end
      
    end
    
    # not looking at saved states, but not generating new states either
    state :paused do
      
      def update
        
      end
      
      def draw
        
      end
      
    end
    
    # generating new states, moving forward in time
    state :running do 
      
      def update
        on_update
      end
      
      def draw
        
      end
      
    end
    # ----------
    
    event :run do
      transition :paused => :running
    end
    
    after_transition :on => :run, :do => :on_run
    
    
    event :pause do
      transition :running => :paused
    end
    
    after_transition :on => :pause, :do => :on_pause
  end
  
  # Can only step back in time if there is saved history to replay
    # paused => replaying    (initial step back)
    # replaying => replaying (continue to replay)
  def step_back
    if running?
      # ERROR: can't step back in running state (must pause first)
      return false # state_machine returns false when event fails
    else
      if history_available?
        # !running? and history_available?
        if paused?
          on_time_travel_start
          self.execution_state = 'replaying'
        end
        
        on_step_back()
        return @i
      else
        # ERROR: no history - at the beginning of time
        # (@i == 0)
        return @i
      end
    end
  end
  
  # Step forward through history, or return to the present (paused state).
  # Stepping forward while paused resumes normal execution.
    # replaying => replaying (most of the time)
    # replaying => paused    (if returning to the 'present' in time travel)
    # paused => running      ()
    # running => running     (continue to run)
  def step_forward
    if replaying?
      on_step_forward()
      
      if returned_to_present?
        self.execution_state = 'paused'
        on_return_to_present()
      end
    elsif paused?
      self.execution_state = 'running'
      on_update()
    elsif running?
      on_update()
    else
      raise "ERROR: unknown execution state encountered while trying to step forward. state is: #{self.execution_state.inspect}"
    end
    
    
    return @i
  end
  
  
  
  state_machine :time_travel_state, :initial => :main_timeline do
    state :main_timeline do
      
    end
    
    state :alternate_timeline do
      
    end
    # ----------
    
    event :change_the_past do
      # can splinter from the main timeline
      transition :main_timeline => :alternate_timeline
      
      # can splinter from one AU into another AU
      transition :alternate_timeline => :alternate_timeline
    end
    
    after_transition :on => :change_the_past, :do => :on_change_the_past
  end
  
  
  
  # ==== for debugging ====
  
  def to_s
    "controller i: #{@i};  @live_code i: #{@live_code.i.inspect}; @live_code value: #{@live_code.inner.value.inspect}"
  end
  
  # =======================
  
  
  private
  
  
  
  def history_available?
    return @i > 0
  end
  
  def returned_to_present?
    # p @branch_i == @i
    return @branch_i == @i
  end
  
  def on_return_to_present
    @branch_i = nil
  end
  
  # on the first step back in time from paused state, take special actions
  def on_time_travel_start
    # save index of "present" time, so we know where it is when we see it again
    @branch_i = @i
  end
  
  # step back through history that has already been written
  def on_step_back
    @i -= 1
    
    @live_code.step_back
  end
  
  # step forward through history that has already been written
  def on_step_forward
    @i += 1
    
    @live_code.step_forward
  end
  
  # step forward and generate new state
  def on_update
    @i += 1
    
    # TODO: generate new state
    @live_code.update
    puts "live code data: #{@live_code.inner.value.inspect}"
  end
  
  def on_run
    
  end
  
  def on_pause
    
  end
  
  
  
  # dynamic reloading of code can possibly cause the creation of new, alternate timelines, depending on the current state of the controller
  def on_successful_reload
    if replaying?
      self.change_the_past
    end
  end
  
  def on_change_the_past
    # create new timeline
    # + duplicate history states into new objects
    # + point index to new history states
    # + change execution state to :running in order to generate new state
  end
  
  # "reading steiner" is a concept from steins;gate, a time-travel anime.
  # In the show, it means the ability to sense that the timeline has changed.
    # (Wait, that actually refers to change by d-mail. You don't move through time persay, but the world line moves around you. If you time leap / take a time machine back, and then cause a change - without incurring a time paradox - that's "opening steins;gate" [S01 E23, "Open the Steins Gate"])
    # wait no -- it's only opening steins gate when you cause a bifurcation in the system and enter a new attractor field. the only known mechanism for doing that is to decieve yourself and the world, changing events while maintaining the apperance of un-change. (krisu appears dead, but she is actually alive)
end

