
class UI_Model
  def initialize
    super()
    
    
    @step_delay = 10
    @step_i = 0
  end
  
  
  
  state_machine :update_mode, :initial => :manual_stepping do
    state :manual_stepping do
      
    end
    
    state :auto_stepping do
      
    end
    
    state :running do
      
    end
    
    # ----------
    
    event :shift_manual do
      transition any => :manual_stepping
    end
    
    event :shift_auto do
      transition any => :auto_stepping
    end
    
    event :shift_run do
      transition any => :running
    end
  end
  
  def auto_step?
    if update_mode_name == :auto_stepping
      
      out  = 
        if @step_i == 0
          true
        else
          false
        end
      
      # periodic counter
      @step_i += 1;
      @step_i = @step_i % @step_delay
      
      return out 
    else
      return false
    end
  end
  
  
  
end
