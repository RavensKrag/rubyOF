class History
  attr_reader :inner, :i
  
  def initialize(inner)
    @inner = inner # object whose history is being saved (active object)
    @i = 0
    
    @data  = [] # serialized data (holds all data)
    @cache = [] # live objects (often only a subset of @data)
  end
  
  
  
  # update the inner item
  def update
    @inner.update
    
    @i += 1
  end
  
  # save new item to the head of the history queue
  def save
    @cache << @inner
  end
  
  
  def step_forward
    if @i < @data.length
      
      @i += 1
    end
    
  end
  
  def step_back
    if @i > 0
      
      @i -= 1
    end
  end
  
  
  def each_in_cache
    
  end
end
