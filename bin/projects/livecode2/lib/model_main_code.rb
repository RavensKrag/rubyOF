module Model
  class MainCode < Code
    def initialize
      super()
      
      @payload = 42
    end
    
    # TODO: does the code need to be a model? should it be a controller?
      # it does have to be a model in a sense, as it owns non-spatial data
    # TODO: does this code need access to the entire history, or is it sufficient to only pass it the current state of the space / input?
      # need to understand inputs over time, so that's probably out.
      # understanding space over time might be good for understanding movement?
    # maybe just leave things like this for now
    
    # TODO: initialize objects with proper timing, such that application code can use #initialize instead of having to specify turn 0 actions.
      # currently, turn 0 is not executing. When integrating with RubyOF, see if it is necessary to initialize things with turn 0. I think it was necessary before, because certain parts of RubyOF do not come online until the first update, rather than on initialization. But I may want to handle that at the RubyOF level, instead of in the application code.
    
    def update(turn_number, space_history)
      # Pass key values into the block by using @instance_variables.
      # (local variables can only be passed once - closure binds first value)
      @space_history = space_history
      
      
      super(turn_number) do |on|
        on.turn 0 do
          puts "initial turn"
        end
        
        
        on.turn 1 do
          puts "turn 1"
          
          puts turn_number # => 1
          puts @payload # => 42 # @instance_var is evaluated in lexical scope
          
          @space_history.inner.tap do |space|
            space.value = space.value + 10
          end
          
        end
        
        on.turn 2..10 do |t|
          puts "turn #{t}"
          
          puts turn_number # => 1   # it's a closure; closes on the first value
          
          @space_history.inner.tap do |space|
            space.value = space.value + 10
          end
          
          
          # if t == 5
          #   raise "BOOM"
          # end
        end
      end
      
    end
    
    def draw(window)
      
    end
  end
end
