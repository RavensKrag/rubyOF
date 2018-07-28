# without subclassing Fiber


class StateClass
	def initialize(turn_number:0)
		@i = turn_number
	end
	
	def turn(i) # &block
		until @i == i
			@i += 1
			Fiber.yield
		end
		yield
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
