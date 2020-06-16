
# Maintain some sort of memory about the entire sequence of events
# such that although you only see a small stretch of events at any
# given time, you can compute a delta of what things have elapsed
# since the previous update.
class SequenceMemory
  def initialize
    @prev_msg_queue = []
  end
  
  def delta_from_sample(new_queue)
    # diff = new_queue - @prev_msg_queue
    
    diff = calc_diff(@prev_msg_queue, new_queue)
    
    
    @prev_msg_queue = new_queue
    
    
    return diff
  end
  
  private
  
  # want just the elements of new_queue that do not appear in old_queue
  def calc_diff(old_queue, new_queue)
    # assume full overlap, and then count down from there
    # (both queues should be the same length??)
    
    if old_queue.empty? || new_queue.length > old_queue.length
      # we can tell how many new messages there are without having to read the messages
      new_msg_count = new_queue.length - old_queue.length
      
      
      return new_queue.last(new_msg_count)
      
    elsif new_queue.length == old_queue.length
      # puts "others"
      # need to examine the contents to know if the messages are new or old
      
      len = old_queue.length
      
      ((0)..(len-1)).reverse_each do |i|
        flag = 
          ((i)..(len-1)).all? do |j|
            new_queue[j+i] == old_queue[i]
          end
        if flag
          new_msg_count = i 
          return new_queue.last(new_msg_count)
        end
      end
      
      # NOTE: comparisons are about 284 us each. may need to make comparisons faster in order to go faster??
      
      
      return new_queue
    end
    
    
    
  end
end

