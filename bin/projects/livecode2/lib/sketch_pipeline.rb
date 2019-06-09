
    
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

    
class Pipeline
  def initialize(first)
    @first = first
    @queue = Array.new
  end
  
  def pipe(&block)
    @queue << block
    return self
  end
  
  def value
    @queue.reverse_each.inject(@first) do |prev_obj, curr_block|
      p [prev_obj, curr_block]
      curr_block.call(prev_obj)
    end
  end
end


first = Foo.new
second = Baz.new
third = Bar.new

out =
  Pipeline.new(first)
  .pipe{|x| second.update x }
  .pipe{|x| third.update x }
  .value

p out




    
    # @input_queue
    # .tap{|x| @raw_input_history.update(x) }
    # .tap{|x| @core_input.update(x, self) }
    
