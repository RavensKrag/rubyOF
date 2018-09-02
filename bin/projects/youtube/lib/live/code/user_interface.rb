class UserInterface
	InputData = Struct.new(:timestamp, :turn_number, :method_message, :args)
	
	def initialize
		@input_queue = Array.new
	end
	
	def update(window, live, main)
		parse_inputs(window, live, main, @input_queue)
	end
	
	# Allow rendering of one state, or many
	# -----
	# state     : state machine state name (from Loader)
	# 
	# history   : data structure with the same interface as Array
	#             that holds various Body instances
	#             (live instances, not serialized data)
	# 
	# current_i : index into states, that indicates the current state
	def draw(window, state, history, current_i)
		
	end
	# TODO: change structure so this class has a state machine too, and both the state machine here and the one in Loader are kept in sync by some code in Loader
	
	
	
	def queue_input(timestamp, turn_number, method_name, args)
		input = InputData.new(timestamp, turn_number, method_name, args)
		@input_queue << input
	end
	
	private
	
	# turn raw inputs into input actions
	def parse_inputs(window, live, main, input_queue)
		# Associate input data with index in the input queue, not the index in the list of unprocessed items
		@input_queue.each do |input|
			self.send(
				input.method_message,
				window, live, main,
				input.turn_number,
				*input.args
			)
		end
	end
	

	# I want to visualize inputs happening over time, so I can see what the actualy input signals I'm dealing with are. I need to measure time in both ms and turn count. I also need to see how spatial input (ie, mouse input) relate to the spatial component of data (time and space are linked).
	
	# I want interface code to be able to interact with spatial entities. How would I reference them by name? Variable names? Entity tags (like HTML ID)? Should I always first accquire entities through a spatial query (raycast?).
	
	def mouse_moved(window, live, main, turn_number, x,y)
		@p = [x,y]
	end
	
	def mouse_pressed(window, live, main, turn_number, x,y, button)
		puts "moving mouse"
		# super(x,y, button)
		
		# ofExit() if button == 8
		# # different window systems return different numbers
		# # for the 'forward' mouse button:
		# 	# GLFW: 4
		# 	# Glut: 8
		# # TODO: set button codes as constants?
		
		case button
			when OF_MOUSE_BUTTON_2 # middle click
				@drag_origin = CP::Vec2.new(x,y)
				@camera_origin = window.camera.pos.clone
		end
	end
	
	def mouse_dragged(window, live, main, turn_number, x,y, button)
		# super(x,y, button)
		
		case button
			when OF_MOUSE_BUTTON_2 # middle click
				pt = CP::Vec2.new(x,y)
				d = (pt - @drag_origin)/window.camera.zoom
				window.camera.pos = d + @camera_origin
		end
	end
	
	def mouse_released(window, live, main, turn_number, x,y, button)
		# super(x,y, button)
		
		case button
			when OF_MOUSE_BUTTON_2 # middle click
				
		end
	end
	
	def mouse_scrolled(window, live, main, turn_number, x,y, scrollX, scrollY)
		# super(x,y, scrollX, scrollY) # debug print
		
		zoom_factor = 1.05
		if scrollY > 0
			window.camera.zoom *= zoom_factor
		elsif scrollY < 0
			window.camera.zoom /= zoom_factor
		else
			
		end
		
		puts "camera zoom: #{window.camera.zoom}"
	end
	
	
	
	def key_pressed(window, live, main, turn_number, key)
		# TODO: figure out how to change Loader state from inside here
		# (should probably have to Loader state change API from all callbacks, honestly... maybe just pass Loder or Window or both to all wrapped callbacks? could easily add it to the beginning of the callback list)
		
		# puts key.chr
		puts key
		
		case key
		when (0..127)
			# interpret int:key as ASCII character
			puts "keyboard: '#{key.chr}'"
			case key.chr
			when ' '
				# -- spacebar has been pressed --
				# NOTE: state_name is a symbol, state is a string
				
				case window.live.state_name
				when :running
					puts "pausing..."
					window.live.pause
				when :paused
					puts "resuming..."
					window.live.resume
				end
				
			end
		when OF_KEY_LEFT
			# can't travel to t=0 ; the initial state is not renderable
			window.live.step_back
		when OF_KEY_RIGHT
			window.live.step_forward
		end
	end
	
	def key_released(window, live, main, turn_number, key)
		
	end
end
