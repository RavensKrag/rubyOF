class UpdateFiber
	class Helper
		def turn(t, &block)
			if t.is_a? Integer or t.is_a? Range
				Fiber.yield t, block
			else
				raise TypeError, "Expected one argument, either Integer or Range, but recieved #{i_or_range.class}"
				# NOTE: ArugmentError is for the number of arguments
				#       TypeError seems to be more appropriate for argument type
			end
		end
	end
	
	def initialize(&block)
		@outer_block = block
	end
	
	
	# Use two fibers, that act together in a producer-consumer pattern,
	# to first figure out which blocks of code to execute, and then
	# when to execute those blocks.
	# 
	# @f2 produces, and @f1 consumes.
	def update(turn_number)
		@f2 ||= Fiber.new do |on|
			Fiber.yield # first tick just establishes closure around Helper object
			@outer_block.call(on) # implicity calls Fiber.yield via Helper#turn()
			
			# when @f2 completes final yield, the fiber will still be alive
		end
		
		@f1 ||= Fiber.new do |turn_number|
			helper = Helper.new()
			@f2.resume(helper) # just pass the helper object in, no real work yet
			
			# producer-consumer pattern to deal with blocks
			while @f2.alive?
				target_turn, inner_block = @f2.resume()
				break if target_turn.nil? # @f2 lives for one extra turn because of yield being encapsulated in Helper class.
				
				# Target turn could be an Integer or a Range.
				# === is the equality check used by 'case' statement.
				# This will work as expected for both types.
				turn_range = 
					case target_turn
					when Integer
						(target_turn..target_turn)
					when Range
						target_turn
					end
				
				loop do
					if turn_number < turn_range.min
						# not the correct turn yet. waiting...
						# NO-OP
						turn_number = Fiber.yield :waiting
					elsif turn_range.include? turn_number
						# this is the turn / range of turns, so execute
						inner_block.call(turn_number)
						turn_number = Fiber.yield :executing
					else # turn_number > turn_range.max
						# turn has passed (useful on reload / time travel)
						break
					end
				end
			end
			
			# signal that all parts of the outer block have completed
			:finished # implicit final Fiber.yield
		end
		
		# pass signals from @f1 to the outer calling context
		if @f1.alive?
			return @f1.resume(turn_number)
		else
			return nil
		end
	end
	
end
