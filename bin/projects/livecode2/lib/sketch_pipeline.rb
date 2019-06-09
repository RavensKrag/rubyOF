
    
    # def =>(other)
    #   self
      
    #   other.update(self)
    # end
    
    # @input_queue => @ui_input
    # @input_queue => @raw_input_history => @core_input
    
    
    
    # # elixir code
    # current_user
    # |> Order.get_orders
    # |> Transaction.make_transactions
    # |> Payment.make_payments(true)
    
    
    # # ruby code
    # def =>(other)
    #   other.foo(self,)
    # end
    
    
    # current_user
    # => Order.get_orders
    # => Transaction.make_transactions
    # => Payment.make_payments(true)

class Foo
  attr_accessor :state
  
  def initialize
    @state = 5
  end
  
  def update
      return self
  end
end

class Baz
  attr_accessor :state
  
  def initialize
    @state = 0
  end
  
  def update(x)
    @state += 20 + x.state
    return self
  end
end

class Bar
  attr_accessor :state
  
  def initialize
    @state = 0
  end
  
  def update(x)
    @state += 100 + x.state
    return self
  end
end


require 'fiber' # defines Fiber#alive?

class Pipeline
  def self.open(&block)
    h = Helper.new
    block.call h
    
    h.queue.reverse_each.inject(h.first) do |prev_obj, curr_block|
      p [prev_obj, curr_block]
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


first = Foo.new
second = Baz.new
third = Bar.new

out =
  Pipeline.open do |p| 
    p.start first
    p.pipe{|x| second.update x }
    p.pipe{|x| third.update x }
  end

p out



      



    
    # @input_queue
    # .tap{|x| @raw_input_history.update(x) }
    # .tap{|x| @core_input.update(x, self) }
    
