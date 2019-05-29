module Model
  class MainCode
    def initialize
      @fibers = Hash.new
      
      @payload = 42
    end
    
    def on_reload
      @regenerate_update_thread = true
    end
    
    def update(turn_number, space_history, input_history)
      # TODO: does the code need to be a model? should it be a controller?
        # it does have to be a model in a sense, as it owns non-spatial data
      # TODO: does this code need access to the entire history, or is it sufficient to only pass it the current state of the space / input?
        # need to understand inputs over time, so that's probably out.
        # understanding space over time might be good for understanding movement?
      # maybe just leave things like this for now
      
      
      # TODO: currently, turn 0 is not executing. When integrating with RubyOF, see if it is necessary to initialize things with turn 0. I think it was necessary before, because certain parts of RubyOF do not come online until the first update, rather than on initialization. But I may want to handle that at the RubyOF level, instead of in the application code.
      
      # FIXME: Code is pretty ugly right now. This file should not contain details like how the separate fibers are maintained, or how this class is serialized. Create a parent class with that, such that MainCode < ParentClass. That way, many classes can use this turn-based structure if necessary
      
      
      
      # FIXME: how does passing in the space_history variable in the function signature mesh with the block on UpdateFiber.new ?  Is the block functioning as a closure? What happens if you send a different value to this method on the next iteration? Will it still be closed around the previous value?
      
      
      
      if @fibers[:update].nil? or @regenerate_update_thread
      @fibers[:update] = UpdateFiber.new do |on|
        on.turn 0 do
          puts "initial turn"
        end
        
        
        on.turn 1 do
          puts "turn 1"
          
          space_history.inner.tap do |space|
            space.value = space.value + 10
          end
          
        end
        
        on.turn 2..10 do |t|
          puts "turn #{t}"
          
          space_history.inner.tap do |space|
            space.value = space.value + 10
          end
          
        end
        
        # system takes one additional step to do nothing,
        # while it processes the :finished signal from UpdateFiber
      end
      @regenerate_update_thread = false
      end
      
      
      
      # This must be last, so the yield from the fiber can return to LiveCode.
      # But if the UI code executes before turn 0, then nothing will render.
      # TODO: consider separate method for UI code.
      out = @fibers[:update].update turn_number
      
      puts "#{turn_number} => #{out}"
      # possible out states = [:waiting, :executing, :finished]
      
      # return true if update was successful (needed by History)
      if out == :finished || out == nil
        return false
      else
        return true
      end
    end
    
    def draw(window)
      
    end
    
    
    
    
  
    def to_yaml_type
      "!ruby/object:#{self.class}"
    end
    
    def encode_with(coder)
      puts "    saving, in body"
      
      var_names = 
        self.instance_variables
        .collect{|sym| sym.to_s }
        .reject{|x| x.include? '@fibers' }
                    
      # var_values = var_names.collect{|x| self.instance_variable_get x }
      
      
      
      # from Text entity implementation
      data = Hash.new
      
      var_names.each do |var_name|
        var = self.instance_variable_get var_name
        
        # for most instance variables, just let YAML take care of it
        # but for certain types, we need to take manual control
        # serialized_var =
        #   case var
        #   when RubyOF::TrueTypeFont
        #     # save just the inner settings object
        #     var.instance_variable_get '@settings'
        #   else # default handler
        #     var
        #   end
        serialized_var = var
        
        data[var_name.to_s.gsub('@', '')] = serialized_var
      end
      
      # p self.instance_variables
      # ^ has the @ symbol in front
      
      coder.represent_map to_yaml_type, data
    end
    
    def init_with(coder)
      # Code taken from Text entity, but should work here as well. Still dealing with a PORO.
      
      
      
      # Don't need to call initialize, as Entity types are plain-old Ruby objects. There is no underlying C++ data type that must be initialized. Thus, we can just set the instance variables here, and be done.
      
      @fibers = Hash.new
      
      # p coder.map
      
      coder.map.each do |var_name, value|
        # deserialized_var = 
        #   case value
        #   when RubyOF::TrueTypeFontSettings
        #     RubyOF::ResourceManager.instance.load value
        #   else # default handler
        #     value
        #   end
        deserialized_var = value
        
        # this is a real object now, do something with it
        # (or may have to pass this to initialize? idk)
        self.instance_variable_set "@#{var_name}", deserialized_var
      end
    end
    
  end
end
