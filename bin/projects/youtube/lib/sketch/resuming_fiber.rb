# without subclassing Fiber


class StateClass
	def initialize(turn_number:0, step_by:1)
		@i = turn_number
		@step = step_by
	end
	
	def turn(i) # &block
		# advance the counter, one turn at a time
		while @i < i
			@i += @step
			Fiber.yield
		end
		
		# guard the yield with another condition so if
		# the counter is initialized past the condition
		# the yield will never trigger.
		# (This is the key to skipping certain blocks in the Fiber.)
		if @i == i
			yield
		end
	end
end



# --- main ---
puts "initialize"
@state ||= StateClass.new(turn_number:0)
@fiber ||= Fiber.new do |s|
	s.turn 0 do
		puts "hello"
	end
	
	s.turn 1 do
		puts "world"
	end
	
	s.turn 100 do
		raise "END OF PROGRAM"
	end
end

loop do
	p @state # show the memory address, to prove object reuse
	puts "update"
	@fiber.resume(@state)
end


# in order to serialize:
# + save @state to remember the current turn
# + DON'T save @fiber (if working inside of YAML serialiaztion, make sure that inside the saved data, @fiber := nil. The contents of @fiber are code, which is already saved in a file. Don't need / don't want to serialize that.)
