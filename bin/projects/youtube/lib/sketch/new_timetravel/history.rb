class History
  attr_reader :inner, :i
  
  def initialize(inner)
    @inner = inner # object whose history is being saved (active object)
    @present = nil # pointer to the object in @inner before time travel
    @i = 0
    
    @data  = [] # serialized data (holds all data)
    @cache = [] # live objects (often only a subset of @data)
  end
  
  
  
  # update the inner item
  def update
    @inner.update
    
    # NOTE: model_main_code currently has a Fiber inside of it, and that Fiber can not be serialized properly
    @data  << @inner.to_yaml
    @cache << YAML.load(@data.last)
    
    @i += 1
  end
  
  # FIXME: problem with last step forward:
    # see next two temp files and the terminal
  # possible off-by-one on forward stepping iterations
  def step_forward
    if @i < @data.length-1
      # stepping forward through history
      @i += 1
      
      @inner = @cache[@i]
    elsif @i == @data.length-1
      # returning to present
      @inner = @present
    end
    
  end
  
  def step_back
    if @i > 0
      @i -= 1
      
      # TODO: get rid of the Fiber problem and remove this line
      @present = @inner # need to save the Fiber, which can't be serialized
      
      @inner = @cache[@i]
    end
  end
  
  
  def each_in_cache
    
  end
end
