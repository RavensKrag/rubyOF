# Allocate a ring buffer / circular buffer of a given fixed length.
# Can not remove elements from this collection - not like a queue.
# As you add elements, the effective size grows until you hit the max size.
# At that point, new elements will start to overwrite old elements.
# 
# Declares a pool of objects you can use on init.
# Can't add or remove from the pool - can only use different parts of it.
class RingBuffer
  def initialize(size, klass)
    @buffer = Array.new(size)
    @max_size = size
    
    @max_size.times do |i|
      @buffer[i] = klass.new
    end
    
    @i = nil
    
    @size = 0
  end
  
  def max_size
    return @max_size
  end
  
  def size
    @size
  end
  
  # access
  # (no writing, because we have a fixed pool of objects)
  def [](i)
    if @i.nil?
      @i = 0
    else
      @i += 1
    end
    
    @i = @i % @max_size
    
    @size += 1
    if @size > @max_size
      @size = @max_size
    end
    
    return @buffer[@i]
    
    # TODO: want to save to buffer
    # TODO: want to pull out of buffer
    
      # buffer is of finite length
      # will only store data from the last minute
      # 
      # how do you retrieve data from the buffer?
      # how is it going to be used?
      # will you say "I want the data from absolute time t"?
      # or will you say "I want the data from t timesteps ago"?
      
      
      # what happens if you scrub the timeline back to something that's not in the buffer?
      # for "instant replay" video, that's not a problem
      # because you can't scrub across all time - you don't have a timeline.
      # but when the game engine is hooked up to blender,
      # you have an interface for moving in absolute time.
    
    
  end
  
  def each # &block
    return enum_for(:each) unless block_given?
    
    self.to_a.each do |x|
      yield x
    end
  end
  
  def to_a
    if @size == @max_size
      # consider potential wrap around
      i = @i+1
      return @buffer[i..-1] + @buffer[0..(i-1)]
      # ^ works even when i == @max_size
      #   because when range.start == Array#size, Array#slice returns []
    else
      if @i == nil
        # no elements added yet
        return []
      else
        # slice it similar to a normal array
        return @buffer[0..@i]
      end
    end
    
  end
end

