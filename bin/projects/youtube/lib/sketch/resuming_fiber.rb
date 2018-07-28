# a way to resume a Fiber
# without subclassing Fiber


# Imagine playing a game, and you have a plan to play
# certain moves on certain turns of the game.
# The TurnCounter mechanism, in conjuction with Fiber,
# will allow # you to enact that plan in such a way
# that you can quit the game while it is paused
# and resume play at some other time.
# (serialize Fiber's execution position, but not its data)
# 
# Created to help implement time traveling code
# in the style of Bret Victor's "Inventing on Principle"
# 		https://vimeo.com/36579366
# (Braid-style time travel while creating code)
# and the JavaScript prototype "JS Dares"
# 		http://jsdares.com
# (a learning environment for javascript in the browser)


class TurnCounter
	attr_reader :current_turn
	
	def initialize(turn_number:0)
		@current_turn = turn_number
	end
	
	def turn(i) # &block
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
	end
end



# --- main ---
puts "initialize"
@turns_per_callback = 5
@counter ||= TurnCounter.new(turn_number:0)
# @counter ||= TurnCounter.new()

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
	p @counter # show the memory address, to prove object reuse
	puts "update"
	
	@turns_per_callback.times do |i|
		@fiber.resume(@counter)
	end
end


# current code takes every nth turn. want to *pause* every n turn instead



# in order to serialize:
# + save @state to remember the current turn
# + DON'T save @fiber (if working inside of YAML serialiaztion, make sure that inside the saved data, @fiber := nil. The contents of @fiber are code, which is already saved in a file. Don't need / don't want to serialize that.)
