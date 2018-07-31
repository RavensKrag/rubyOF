class Body
	def update
		@i ||= 0
		
		@fibers[:update] ||= Fiber.new do |on|
			on.turn 0..9 do
				puts "  updating..."
				# if i > 20
				# 	raise "DERP"
				# end
				@i += 1
				# puts @i
			end
			
			on.turn 100 do
				raise "END OF PROGRAM"
			end
			
			# NOTE: Don't use Fiber.yield inside turn() block. turn() already implicitly calls yield. Calling Fiber.yield again will result in the Fiber only running every other tick.
			loop do
				Fiber.yield
			end
		end
		
		@fibers[:update].resume @update_counter
	end
	
	def draw
		# puts "draw"
		
		@fibers[:draw] ||= Fiber.new do |on|
			on.turn 0..9 do
				puts "  drawing..."
				# if i > 20
				# 	raise "DERP"
				# end
			end
			
			# NOTE: Don't use Fiber.yield inside turn() block. turn() already implicitly calls yield. Calling Fiber.yield again will result in the Fiber only running every other tick.
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
		puts "    saving, in body"
		
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
