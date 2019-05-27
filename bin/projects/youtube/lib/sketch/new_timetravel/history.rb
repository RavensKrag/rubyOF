class History
  attr_reader :inner, :i
  
  def initialize(inner)
    @inner = inner # object whose history is being saved (active object)
    @present = nil # pointer to the object in @inner before time travel
    @i = 0
    
    @data  = [] # serialized data (holds all data)
    @cache = [] # live objects (often only a subset of @data)
    
    save() # save initial state as @i == 0
  end
  
  
  
  # update the inner item
  def update
    update_successful = @inner.update
    if update_successful
      save()
      @i += 1
      return true
    else
      return false
    end
  end
  
  def step_forward
    if @i < @data.length
      # stepping forward through history
      @i += 1
      
      @inner = @cache[@i]
    end
    
  end
  
  def step_back
    if @i > 0
      @i -= 1
      
      @present = @inner
      
      @inner = @cache[@i]
    end
  end
  
  
  def each_in_cache
    
  end
  
  def each_data
    
  end
  
  def length
    return @data.length
  end
  alias :size :length
  
  
  private
  
  
  def save
    @data  << @inner.to_yaml
    @cache << YAML.load(@data.last)
  end
end
