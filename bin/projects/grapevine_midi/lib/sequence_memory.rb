
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
    # puts "queue size (before): #{@prev_msg_queue.size}"
    
    diff = calc_diff(@prev_msg_queue, new_queue)
    
    
    @prev_msg_queue = new_queue
    # puts "queue size (after): #{@prev_msg_queue.size}"
    
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
      
      
      # lengths of both queues are the same, because of conditional above
      len = old_queue.length
      
      
      # check for overlapping k-mers
      # which is to say, segments of size k
      
      (1..len).reverse_each do |k|
        # puts "k: #{k}"
        
        aligned_pairs = old_queue.last(k).zip(new_queue.first(k))
        if aligned_pairs.all?{ |old_x, new_x| old_x == new_x }
          return new_queue.last(len-k)
        end
      end
      
      # 
      # raise "ERROR: this code should be unreachable"
      return new_queue # all new messages?
      
      
    end
    
  end
end

