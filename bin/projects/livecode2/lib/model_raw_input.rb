require 'set'


module Model

class RawInput
  attr_reader :active_keys
  
  def initialize
    @active_keys = Set.new
  end
  
  def on_reload
    initialize()
  end
  
  
  def update(input_queue)
    
    
    return self # output truthy to tell History to save state
  end
  
end


end
