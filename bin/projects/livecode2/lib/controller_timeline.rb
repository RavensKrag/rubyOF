# TODO: remove @ui_input - it should be managed by Window, not here


require 'state_machine'

class Timeline
  attr_reader :i, :branch_i
  
  def initialize(input_history, ui_input, core_input, main_code, space)
    super()
    
    @input_history  = input_history # raw user input data (drives sequences)
    @ui_input       = ui_input      # reads only current frame of input
    @core_input     = core_input    # reads entire history to launch events
    
    @code_history   = main_code     # code env with live reloading
    @space_history  = space         # space containing main entities
    
    
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
      transition :paused => :running, :if => :no_error?
    end 
    
    after_transition :on => :play, :do => :on_play
    
    
    event :pause do
      transition :running => :paused
    end
    
    after_transition :on => :pause, :do => :on_pause
  end
  
  
  state_machine :error_flag, :initial => :no_error do
    state :no_error do
      
    end
    
    state :error do
      
    end
    
    
    event :error_detected do
      transition :no_error => :error
    end
    
    after_transition :on => :error_detected, :do => :on_error_detected
    
    
    event :error_fixed do
      transition :error => :no_error
    end
    
    after_transition :on => :error_fixed, :do => :on_error_fixed
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
  
  
  # ==== for debugging ====
  
  def to_s
    msg = [
      "state: #{self.execution_state}",
      "controller i: #{@i}",
      "model i: #{[@code_history.i,
                   @space_history.i,
                   @input_history.i]}",
      "cache size: #{[@code_history.length,
                      @space_history.length,
                      @input_history.length]}",
      "@space_history: #{@space_history.inner.instance_variable_get(:@value).inspect}"
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
    @code_history.step_back
    @space_history.step_back
  end
  
  # step forward through history that has already been written
  def on_step_forward
    @i += 1
    
    @input_history.step_forward
    @code_history.step_forward
    @space_history.step_forward
  end
  
  # step forward and generate new state
  def on_update(window, input_queue)
    # generate new state
    # TODO: if you have more than one dynamic code object, make sure all dynamic code is properly loaded before advancing the state.
    # TODO: it might be possible for certain pieces of dynamic code to fail, and not others, causing synchronization issues. watch out for that.
    
    
    # @space_history = History.new(Model::CoreSpace.new)
    # @raw_input_history = History.new(LiveCode.new(
    # @code_history =  History.new(
    
    puts "--- controller on_update BEGIN ---"
    
    @i += 1
    
    # FIXME: make sure all classes return self on update, otherwise the Pipeline will not work as expected
    
    # input_queue -> @input_history -> @core_input
    signal = 
      Pipeline.open do |p| 
        p.start input_queue
        p.pipe{|x| @input_history.update x }
        p.pipe{|x| @core_input.update x => window }
      end
    # TODO: make sure there is a signal being returned here, and then deal with the error and stop early if necessary
    
    
    # @space_history -> @code_history ---> signal
    signal = @code_history.update @i, @space_history
    @space_history.update
      # p signal.class
    if signal == :error
      self.error_detected()
    end
    # NOTE: must update space LAST, otherwise any changes to space made by @code_history will not be saved until the next frame.
    
    
    # FIXME: need a way to generate new state from old user input, after code is changed (go back in time and change the past code, but keep the same inputs - interpret them differently)
      # will do this once I have mulitple timelines that can be edited
    
    puts "--- controller on_update END ---"
  end
  
  def on_play
    
  end
  
  def on_pause
    
  end
  
  
  
  
  def on_error_detected
    puts "error detected"
    self.pause()
  end
  
  def on_error_fixed
    
  end
  
  
end
