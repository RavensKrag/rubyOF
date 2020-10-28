
class Pipeline
  def self.open(&block)
    h = Helper.new
    block.call h
    
    # p h.queue
    h.queue.each.inject(h.first) do |prev_obj, curr_block|
      curr_block.call(prev_obj)
    end
  end
  
  class Helper
    attr_reader :first, :queue
    
    def initialize
      @first = first
      @queue = Array.new
    end
    
    def start(first)
      @first = first
    end
    
    def pipe(&block)
      raise "ERROR: First line in Pipeline block must call #{self.class}#start. Pass in a single object to #start to initate the pipeline. Then, subsequent lines can call #pipe." if @first.nil?
      
      @queue << block
    end
  end
  
end
