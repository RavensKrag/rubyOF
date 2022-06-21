# Allocate a ring buffer / circular buffer of a given fixed length.
# Can not remove elements from this collection - not like a queue.
# As you add elements, the effective size grows until you hit the max size.
# At that point, new elements will start to overwrite old elements.
class RingBuffer
  def initialize(size)
    @buffer = Array.new(size)
    @max_size = size
    @i = nil
    
    @size = 0
  end
  
  def max_size
    return @max_size
  end
  
  def size
    @size
  end
  
  def <<(data)
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
    
    @buffer[@i] = data
  end
  
  def push(*args)
    args.each do |x|
      self << x
    end
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

