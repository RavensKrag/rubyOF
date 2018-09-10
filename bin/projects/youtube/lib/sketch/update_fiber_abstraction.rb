
# draft 1
Fiber.new do |turn_number|
	if turn_number == 0
		
	end

	turn_number = Fiber.yield
	
	if turn_number == 1
		
	end
	
	turn_number = Fiber.yield
	
	if turn_number == 2
		
	end
	
	turn_number = Fiber.yield
	
	if turn_number == 3
		
	end
	
	turn_number = Fiber.yield
	
	if turn_number == 4
		
	end
	
	turn_number = Fiber.yield
	
	if turn_number == 10
		
	end
	
	turn_number = Fiber.yield
	
	if (11..30).include? turn_number
		
	end
	
	
	
	Fiber.yield
end








# draft 2
Fiber.new do |turn_number|
	if 0 === turn_number
		
	end

	turn_number = Fiber.yield
	
	if 1 === turn_number
		
	end
	
	turn_number = Fiber.yield
	
	if 2 === turn_number
		
	end
	
	turn_number = Fiber.yield
	
	if 3 === turn_number
		
	end
	
	turn_number = Fiber.yield
	
	if 4 === turn_number
		
	end
	
	turn_number = Fiber.yield
	
	if 10 === turn_number
		
	end
	
	turn_number = Fiber.yield
	
	if (11..30) === turn_number
		
	end
	
	
	
	Fiber.yield
end


# draft 3

turns = Array.new # list of tuples: [turn_number, associated_block]

Fiber.new do |turn_number|
	turn, block = turns[0]
	
	if turn === turn_number
		block.call
	end
	
	turn_number = Fiber.yield
	
	
	
	
	loop do
		
	end
	
	Fiber.yield
end








class FooInner
	def initialize(parent)
		@parent = parent
		@final_turn = 0
	end
	
	
	def turn(target, &block)
		case target
			when Integer
				if target < @final_turn
					raise "ERROR: Turns specified out of order. Specified turn (#{target}) is less than current final turn (#{@final_turn})"
				end
				
				@final_turn = target
			when Range
				if target.min < @final_turn
					raise "ERROR: Turns specified out of order. Specified turn (#{target.min}) is less than current final turn (#{@final_turn})"
				end
				
				@final_turn = target.max
			else
				raise "ERROR: Unexpected input type. Must be either Integer or Range"
		end
		
		# now @final_turn is set
		
		
	end
end

class Foo
	def initialize(turn_number, &block)
		@block = block
		@inner = FooInner.new(self)
	end
	
	def resume(turn_number)
		@fiber ||= Fiber.new do |turn_number|
			
			loop do
				@block.call(@inner)
				
				turn_number = Fiber.yield
			end
		end
		
		
		
		@fiber.resume(turn_number)
	end
end

baz = Foo.new do |on|
	on.turn 0 do
		
	end
	
	on.turn 1 do
		
	end
	
	on.turn 2 do
		
	end
	
	on.turn 3 do
		
	end
	
	on.turn 4 do
		
	end
	
	on.turn 10 do
		
	end
end

baz.resume(turn_number)








# draft 4
class FooHelper
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

body = Proc.new do
	on.turn 0 do
		
	end # 'turn' block automatically calls Fiber.yield
	
	on.turn 1 do
		
	end
	
	on.turn 2 do
		
	end
	
	on.turn 3 do
		
	end
	
	on.turn 4 do
		
	end
	
	on.turn 10 do
		
	end
	
	on.turn 11..20 do
		
	end
end

f2 = Fiber.new |on|
	Fiber.yield
	
	body.call() # implicity calls Fiber.yield via FooHelper#turn()
end

f1 = Fiber.new do |turn_number|
	helper = FooHelper.new()
	f2.resume(helper) # just pass the helper object in, no real work yet
	
	# producer-consumer pattern to deal with blocks
	while f2.alive? do
		target_turn, block = f2.resume()
		
		
		# Target turn could be an Integer or a Range.
		# === is the equality check used by 'case' statement.
		# This will work as expected for both types.
		case target_turn
		when Integer
			# execute block once, then move on
			while turn_number < target_turn # not turn yet, so wait
				turn_number = Fiber.yield
			end
			
			if target_turn === turn_number # it is the turn, so execute
				block.call()
			end
			
			# if the turn has passed, do nothing
		when Range
			# execute block many times, moving on after range is cleared
			
			loop do
				if turn_number < target_turn.min
					# not in the range yet. waiting...
				elsif target_turn === turn_number
					# inside the range
					block.call()
				elsif turn_number > target_turn.max
					# after the range.
					break
				else
					raise "ERROR: Range bounds not defined as expected. Range: #{target_turn}."
				end
				
				turn_number = Fiber.yield
			end
			
		end
	end
end

# -- main
turn_number = 0
loop do
	f1.resume(turn_number)
	turn_number += 1
end









# draft 5
class InputTrack
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
		@f2 ||= Fiber.new |on|
			Fiber.yield # first tick just establishes closure around Helper object
			@outer_block.call(on) # implicity calls Fiber.yield via Helper#turn()
		end
		
		@f1 ||= Fiber.new do |turn_number|
			helper = Helper.new()
			@f2.resume(helper) # just pass the helper object in, no real work yet
			
			# producer-consumer pattern to deal with blocks
			while @f2.alive? do
				target_turn, inner_block = @f2.resume()
				
				
				# Target turn could be an Integer or a Range.
				# === is the equality check used by 'case' statement.
				# This will work as expected for both types.
				case target_turn
				when Integer
					# execute block once, then move on
					while turn_number < target_turn # not turn yet, so wait
						turn_number = Fiber.yield
					end
					
					if target_turn === turn_number # it is the turn, so execute
						inner_block.call()
					end
					
					# if the turn has passed, do nothing
				when Range
					# execute block many times, moving on after range is cleared
					
					loop do
						if turn_number < target_turn.min
							# not in the range yet. waiting...
						elsif target_turn === turn_number
							# inside the range
							inner_block.call()
						elsif turn_number > target_turn.max
							# after the range.
							break
						else
							raise "ERROR: Range bounds not defined as expected. Range: #{target_turn}."
						end
						
						turn_number = Fiber.yield
					end
					
				end
			end
		end
		
		@f1.resume
	end
end


# -- main
input = InputTrack.new do |on|
	on.turn 0 do
		
	end # 'turn' block automatically calls Fiber.yield
	
	on.turn 1 do
		
	end
	
	on.turn 2 do
		
	end
	
	on.turn 3 do
		
	end
	
	on.turn 4 do
		
	end
	
	on.turn 10 do
		
	end
	
	on.turn 11..20 do
		
	end
end


turn_number = 0
loop do
	input.update(turn_number)
	turn_number += 1
end







# draft 6
class InputTrack
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
		@f2 ||= Fiber.new |on|
			Fiber.yield # first tick just establishes closure around Helper object
			@outer_block.call(on) # implicity calls Fiber.yield via Helper#turn()
		end
		
		@f1 ||= Fiber.new do |turn_number|
			helper = Helper.new()
			@f2.resume(helper) # just pass the helper object in, no real work yet
			
			# producer-consumer pattern to deal with blocks
			while @f2.alive? do
				target_turn, inner_block = @f2.resume()
				
				
				# Target turn could be an Integer or a Range.
				# === is the equality check used by 'case' statement.
				# This will work as expected for both types.
				min, core, max = 
					case target_turn
					when Integer
						[target_turn,     target_turn, target_turn    ]
					when Range
						[target_turn.min, target_turn, target_turn.max]
					end
				
				loop do
					signal = 
						if turn_number < min
							# not the correct turn yet. waiting...
							# NO-OP
							nil
						elsif core === turn_number
							# this is the turn / range of turns, so execute
							inner_block.call(turn_number)
							:non_blank # pseudo-return
						else # turn_number > max
							# turn has passed (useful on reload / time travel)
							break
						end
					
					turn_number = Fiber.yield signal
				end
			end
			
			# signal that all parts of the outer block have completed
			Fiber.yield :finished
		end
		
		# pass signals from @f1 to the outer calling context
		return @f1.resume(turn_number)
	end
end


# -- main
input = InputTrack.new do |on|
	on.turn 0 do
		
	end # 'turn' block automatically calls Fiber.yield
	
	on.turn 1 do
		
	end
	
	on.turn 2 do
		
	end
	
	on.turn 3 do
		
	end
	
	on.turn 4 do
		
	end
	
	on.turn 10 do
		
	end
	
	on.turn 11..20 do
		
	end
end


history = Array.new
turn_number = 0
loop do
	signal = input.update(turn_number)
	
	case signal
	when :non_blank # some transformation was performed by #update
		history << turn_number
	when :finished
		history << -1
	end
	
	turn_number += 1
end

# history
# => [0,1,2,3,4,10,11,12,13,14,15,16,17,18,19,20,-1]







# draft 7
class InputTrack
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
		@f2 ||= Fiber.new |on|
			Fiber.yield # first tick just establishes closure around Helper object
			@outer_block.call(on) # implicity calls Fiber.yield via Helper#turn()
		end
		
		@f1 ||= Fiber.new do |turn_number|
			helper = Helper.new()
			@f2.resume(helper) # just pass the helper object in, no real work yet
			
			# producer-consumer pattern to deal with blocks
			while @f2.alive? do
				target_turn, inner_block = @f2.resume()
				
				
				# Target turn could be an Integer or a Range.
				# === is the equality check used by 'case' statement.
				# This will work as expected for both types.
				min, core, max = 
					case target_turn
					when Integer
						[target_turn,     target_turn, target_turn    ]
					when Range
						[target_turn.min, target_turn, target_turn.max]
					end
				
				loop do
					signal = 
						if turn_number < min
							# not the correct turn yet. waiting...
							# NO-OP
							nil
						elsif core === turn_number
							# this is the turn / range of turns, so execute
							inner_block.call(turn_number)
							:non_blank # pseudo-return
						else # turn_number > max
							# turn has passed (useful on reload / time travel)
							:turn_has_passed
						end
					
					turn_number = Fiber.yield signal
					
					break if signal == :turn_has_passed
				end
			end
			
			# signal that all parts of the outer block have completed
			Fiber.yield :finished
		end
		
		# pass signals from @f1 to the outer calling context
		return @f1.resume(turn_number)
	end
end


# -- main
input = InputTrack.new do |on|
	on.turn 0 do
		
	end # 'turn' block automatically calls Fiber.yield
	
	on.turn 1 do
		
	end
	
	on.turn 2 do
		
	end
	
	on.turn 3 do
		
	end
	
	on.turn 4 do
		
	end
	
	on.turn 10 do
		
	end
	
	on.turn 11..20 do
		
	end
end


history = Array.new
turn_number = 0
loop do
	signal = input.update(turn_number)
	
	case signal
	when :non_blank # some transformation was performed by #update
		history << turn_number
	when :finished
		history << -1
	end
	
	turn_number += 1
end

# history
# => [0,1,2,3,4,10,11,12,13,14,15,16,17,18,19,20,-1]
