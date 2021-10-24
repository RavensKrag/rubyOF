class BlenderHistory
  def initialize
    @buffer = Array.new
    @state = Array.new
  end
  
  # put new message in history buffer
  def write(message)
    @buffer << message
    
    return self
  end
  
  # read from history buffer
  def read # &block
    # t0 = RubyOF::Utils.ofGetElapsedTimeMicros/1000.0
    
    @buffer = compress_history(@buffer)    
    
    @buffer.each do |message|
      yield message
      
      @state << message
    end
    
    @state = compress_history(@state)
    
    @buffer.clear
    
    # t1 = RubyOF::Utils.ofGetElapsedTimeMicros/1000.0
    # puts "time: #{t1-t0}"
    
    return self
  end
  
  # After this method is called, the next call to #read
  # should return the full state up to this point.
  # This will allow for the full restoration of the state.
  def on_reload
    File.open(PROJECT_DIR/'bin'/'data'/'tmp_all.json', 'w') do |f|
      f.puts JSON.pretty_generate @state
    end
    
    @buffer = @state.clone
    
    
    return self
  end
  
  private
  
  def compress_history(message_history)
    material_maps, other_messages = message_history.partition do |message|
      message['type'] == 'material_mapping'
    end
    
    other_messages = other_messages.reverse.uniq{ |message|
      [ message['type'], message['name'] ]
    }.reverse
    
    material_maps = material_maps.reverse.uniq{ |message|
      [ message['type'], message['object_name'], message['material_name'] ]
    }.reverse
    
    return other_messages + material_maps
  end
end
