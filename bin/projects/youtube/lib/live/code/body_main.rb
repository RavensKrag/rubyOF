class Body
	def update
		@i ||= 2
		@update_counter ||= TurnCounter.new
		
		@fibers[:update] ||= Fiber.new do |on|
			on.turn 0..9 do
				# puts "updating..."
				# if i > 20
				# 	raise "DERP"
				# end
				@i *= 2
				# puts @i
				
				Fiber.yield
			end
			
			loop do
				Fiber.yield
			end
		end
		
		@fibers[:update].resume @update_counter
	end
	
	def draw
		# puts "draw"
		@draw_counter ||= TurnCounter.new
		
		@fibers[:draw] ||= Fiber.new do |on|
			on.turn 0..9 do
				# puts "drawing..."
				# if i > 20
				# 	raise "DERP"
				# end
				Fiber.yield
			end
			
			loop do
				Fiber.yield
			end
		end
		
		@fibers[:draw].resume @draw_counter
	end
	
	def on_exit
		
	end
	
	# save the entire state of the world.
	# return the result, don't output to file here.
	def save
		out = Hash.new
		
		
		var_names = 
			self.instance_variables
			.reject{|x| x.to_s.include? '@fibers' }
									
		var_values = var_names.collect{|x| self.instance_variable_get x }
		
		out[:instance_vars] = var_names.zip(var_values).to_h
		
		
		
		return out
	end
	
	# restore from saved data
	def load(data)
		
	end
	
	
	class << self
		def from_data(data)
			obj = self.new
			obj.load(data)
			
			return obj
		end
	end
end
