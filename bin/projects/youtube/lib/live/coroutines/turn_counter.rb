
class TurnCounter
	attr_accessor :current_turn
	
	def initialize(turn_number:0)
		@current_turn = turn_number
	end
	
	def turn(i_or_range) # &block
		if i_or_range.is_a? Integer
			i = i_or_range
			# advance the counter, one turn at a time
			while @current_turn < i
				@current_turn += 1
				Fiber.yield
			end
			
			# guard the yield with another condition so if
			# the counter is initialized past the condition
			# the yield will never trigger.
			# (This is the key to skipping certain blocks in the Fiber.)
			if @current_turn == i
				yield
			end
			
		elsif i_or_range.is_a? Range
			range = i_or_range
			# advance the counter, one turn at a time
			while @current_turn < range.max
				@current_turn += 1
				Fiber.yield
				
				# guard the yield with another condition so if
				# the counter is initialized past the condition
				# the yield will never trigger.
				# (This is the key to skipping certain blocks in the Fiber.)
				if range.include? @current_turn
					yield
				end
			end
		else
			raise TypeError, "Expected one argument, either Integer or Range, but recieved #{i_or_range.class}"
			# NOTE: ArugmentError is for the number of arguments
			#       TypeError seems to be more appropriate for argument type
		end
		
		
		
	end
end

 
