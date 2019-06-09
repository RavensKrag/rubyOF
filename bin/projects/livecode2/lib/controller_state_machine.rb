require 'state_machine'

class Controller
  attr_reader :i, :branch_i
  
  
  
  def initialize(input_history, ui_input, core_input, main_code, space)
    super()
    
    @input_history  = input_history # raw user input data (drives sequences)
    @ui_input       = ui_input      # reads only current frame of input
    @core_input     = core_input    # reads entire history to launch events
    
    @main_code      = main_code     # code env with live reloading
    @core_space     = space         # space containing main entities
    
    
    @i = 0
  end
  
  
  
  state_machine :execution_state, :initial => :paused do
    # replaying saved states
    state :replaying do
      
      def update(*args)
        
      end
      
      def draw
        
      end
      
    end
    
    # not looking at saved states, but not generating new states either
    state :paused do
      
      def update(*args)
        
      end
      
      def draw
        
      end
      
    end
    
    # generating new states, moving forward in time
    state :running do 
      
      def update(*args)
        on_update(*args)
      end
      
      def draw
        
      end
      
    end
    
    
    state :runtime_error do
      
      def update(*args)
        
      end
      
      def draw
        
      end
      
    end
    # ----------
    
    event :play do
      transition :paused => :running
    end
    
    after_transition :on => :play, :do => :on_play
    
    
    event :pause do
      transition :running => :paused
    end
    
    after_transition :on => :pause, :do => :on_pause
    
    
    event :error_detected do
      transition :running => :runtime_error
    end
    
    event :error_fixed do
      transition :runtime_error => :running
    end
  end
  
  # Can only step back in time if there is saved history to replay
    # paused => replaying    (initial step back)
    # replaying => replaying (continue to replay)
  def step_back
    if running?
      # ERROR: can't step back in running state (must pause first)
      puts "WARNING: #step_back disabled while running. Use #pause first."
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
  # To resume normal execution or step while in 'running' mode, use #update
  
  # Stepping forward while paused resumes normal execution.
  # Don't use #step_forward to advance state in play mode - use #update instead
    # replaying => replaying (most of the time)
    # replaying => paused    (if returning to the 'present' in time travel)
  def step_forward
    if replaying?
      on_step_forward()
      
      if returned_to_present?
        self.execution_state = 'paused'
        on_return_to_present()
      end
    elsif paused?
      # NO-OP
      puts "WARNING: No more history. Use #update to resume execution."
      
    elsif running?
      # NO-OP
      puts "WARNING: #step_forward disabled while running. Use #pause first."
      
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
    msg = [
      "state: #{self.execution_state}",
      "controller i: #{@i}",
      "model i: #{[@main_code.i,
                   @core_space.i,
                   @input_history.i]}",
      "cache size: #{[@main_code.length,
                      @core_space.length,
                      @input_history.length]}",
      "@core_space: #{@core_space.inner.instance_variable_get(:@value).inspect}"
    ].join("; ")
    
    return msg
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
    
    @input_history.step_back
    @main_code.step_back
    @core_space.step_back
  end
  
  # step forward through history that has already been written
  def on_step_forward
    @i += 1
    
    @input_history.step_forward
    @main_code.step_forward
    @core_space.step_forward
  end
  
  # step forward and generate new state
  def on_update(window, input_queue)
    # generate new state
    # TODO: if you have more than one dynamic code object, make sure all dynamic code is properly loaded before advancing the state.
    # TODO: it might be possible for certain pieces of dynamic code to fail, and not others, causing synchronization issues. watch out for that.
    
    
    @i += 1
    
    # FIXME: make sure all classes return self on update, otherwise the pipeline will not work as expected
    
    # input_queue -> @input_history -> @core_input
    Pipeline.open do |p| 
      p.start input_queue
      p.pipe{|x| @input_history.update x }
      p.pipe{|x| @core_input.update x => window }
    end
    
    # @core_space -> @main_code ---> signal
    signal = 
      Pipeline.open do |p| 
        p.start @core_space.update
        p.pipe{|x| @main_code.update @i, x }
      end
    p signal.class
    if signal == :error
      self.error_detected()
    end
  
    # FIXME: need a way to generate new state from old user input, after code is changed (go back in time and change the past code, but keep the same inputs - interpret them differently)
      # will do this once I have mulitple timelines that can be edited
    
  end
  
  def on_play
    
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

