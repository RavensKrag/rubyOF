class Body
	attr_reader :update_counter, :draw_counter
	
	def initialize
		@fibers = Hash.new
		
		# @world  = Space.new
		# @screen = Space.new
		
		@update_counter = TurnCounter.new
		@draw_counter   = TurnCounter.new
	end
end
