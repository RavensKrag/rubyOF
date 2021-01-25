class History
  def initialize
    @@empty ||= {}.freeze
    
    @data = @@empty
    @diff = @@empty
  end
  
  def write(data)
    @diff = @diff.merge data # merge with existing diff
    
    return self
  end
  
  def read
    @data = @data.merge @diff
    
    out = @diff
    @diff = @@empty # or equivalent empty collection
    
    return out
  end
  
  def on_reload
    # new diff must progress from nothing to current point
    # in order to fully restore the state
    @diff = @data.merge @diff
    
    p @diff
    
    # merge data with existing diff
    # but ignore the interrupt commands
    if @diff.has_key? 'interrupt'
      @diff.delete('interrupt')
    end
    
    # also remove the timestamps
    if @diff.has_key? 'timestamps'
      @diff.delete('timestamps')
    end
    
    
    File.open(PROJECT_DIR/'bin'/'data'/'blender_data.json', 'w') do |f|
      f.puts JSON.pretty_generate @diff
    end
    
    
    return self
  end
end
