
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
				# TODO: send signal to outside usig Fiber.yield when the block is actually called. want to be able to visualize when code is actually being executed, versus when there are just NO-OP blocks (ie, Main is waiting)
				# (probably need a special marker for "finished" as well)
				
				# should be able to create big chunks of empty time between code and user inputs. with some GUI tool, you can cut out the empty time later as an effeciency tweak. There thus needs to be a difference between deleting the "notes" in a particular time span, and deleting the time span itself.
				
				# having empty time between the end of code execution and user input is useful, because you can imagine some inputs, before assigning real code to them. alternatively, you may want to transform the space with a combination of direct input, and code.
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

 
