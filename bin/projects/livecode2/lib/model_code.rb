# 
# This is a basic class that should be extended by actual application code.
# 
module Model
  class Code
    def initialize
      @fibers = Hash.new
    end
    
    def on_reload
      @regenerate_update_thread = true
    end
    
    def update(turn_number, &block)
      if @fibers[:update].nil? or @regenerate_update_thread
      @fibers[:update] = UpdateFiber.new do |on|
        block.call(on)
        
        # system takes one additional step to do nothing,
        # while it processes the :finished signal from UpdateFiber
      end
      @regenerate_update_thread = false
      end
      
      
      
      # This must be last, so the yield from the fiber can return to LiveCode.
      # But if the UI code executes before turn 0, then nothing will render.
      # TODO: consider separate method for UI code.
      out = @fibers[:update].update turn_number
      
      puts "#{self.class} : turn #{turn_number} => #{out.inspect}"
      # possible out states = [:waiting, :executing, :finished]
      
      
      # Only return symbols on error (interface for History)
      # when there is no error, you can return anything you like.
      # Live code errors will be handled by live loader,
      # so the only "error" is when you reach the end of execution.
      # (need to output an error code so History doesn't save any more states)
      case out
      when :finished, nil
        return :finished
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
      puts "    saving, in Model::Code > #{self.class}"
      
      var_names = 
        self.instance_variables
        .collect{|sym| sym.to_s }
        .reject{|x| x.include? '@fibers' }
        .reject{|x| x.include? 'history' }
                    
      # var_values = var_names.collect{|x| self.instance_variable_get x }
      
      # puts "history inner value: #{@space_history.inner.value}" 
      
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
