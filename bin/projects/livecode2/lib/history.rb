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
  
  # signal seems to either be self, or an error code (Symbol)
  
  def update(*args)
    puts "History#update : step #{@i} -> #{@i + 1} for #{@inner.class}"
    signal = @inner.update(*args)
    if signal.is_a? Symbol # symbols are used for error codes
      puts "update failed => #{signal.inspect}"
      return signal # pass signal to calling controller for error handling
    else
      @i += 1
      save()
      return self
    end
      puts "---------"
  end
  
  def step_forward
    if @i < @data.length-1
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
    puts "saving... #{@inner.class}"
    @data  << @inner.to_yaml
    puts "data size: #{@data.size}"
    @cache << YAML.load(@data.last)
  end
end
