class Body
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
			serialized_var =
				case var
				when RubyOF::TrueTypeFont
					# save just the inner settings object
					var.instance_variable_get '@settings'
				else # default handler
					var
				end
			
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
			deserialized_var = 
				case value
				when RubyOF::TrueTypeFontSettings
					RubyOF::ResourceManager.instance.load value
				else # default handler
					value
				end
			
			# this is a real object now, do something with it
			# (or may have to pass this to initialize? idk)
			self.instance_variable_set "@#{var_name}", deserialized_var
		end
	end
end
