
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
    
    # align segments of old_queue to the new_queue
    # do not have to check all k-mers:
    #   only contiguous segments from the tail end of old_queue
    # stop when you find the first match, ie, the longest possible one
    
    k_mers = 
      ((1)..(old_queue.length)).collect do |i|
        old_queue.last(i)
      end
    
    overlap_length = 0;
    k_mers.reverse_each do |seq|
      # puts "#{new_queue.first(seq.length)} vs #{seq}"
      
      if new_queue.first(seq.length) == seq
        overlap_length = seq.length
        break
      end
    end
    
    
    if overlap_length == 0
      # no items in sequenced matched
      # thus, data is all brand new
      return new_queue
    else
      # 
      return new_queue.last(new_queue.size - overlap_length)
    end
    
  end
end
