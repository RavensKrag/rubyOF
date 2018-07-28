class Body
	def update
		@i ||= 2
		
		@fibers[:update] ||= Fiber.new do
			10.times do |i|
				puts "updating..."
				# if i > 20
				# 	raise "DERP"
				# end
				@i *= 2
				puts @i
				
				Fiber.yield
			end
			
			loop do
				Fiber.yield
			end
		end
		
		@fibers[:update].resume
	end
	
	def draw
		# puts "draw"
		
		@fibers[:draw] ||= Fiber.new do
			10.times do |i|
				puts "drawing..."
				# if i > 20
				# 	raise "DERP"
				# end
				Fiber.yield
			end
			
			loop do
				Fiber.yield
			end
		end
		
		@fibers[:draw].resume
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
end
