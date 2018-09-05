class Body
	attr_reader :update_counter, :draw_counter
	attr_reader :turn
	
	def initialize
		@fibers = Hash.new
		
		# @world  = Space.new
		# @screen = Space.new
		
		@update_counter = TurnCounter.new
		@draw_counter   = TurnCounter.new
		
		@world_space  = Space.new
		@screen_space = Space.new
		
		@turn = 0
	end
end
