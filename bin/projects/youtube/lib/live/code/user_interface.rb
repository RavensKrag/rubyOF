class UserInterface
	InputData = Struct.new(:timestamp, :turn_number, :method_message, :args)
	
	def initialize(window)
		@input_queue = Array.new
		@last_input = 0
		
		
		@world_space  = Space.new
		@screen_space = Space.new
		
		
		# TODO: make sure that the dsl_load interface always goes through the resource manager. more importantly: I created the same font here and in Body. Need to make sure it is only loaded once.
		
		@font = 
			RubyOF::TrueTypeFont.dsl_load do |x|
				# TakaoPGothic
				# ^ not installed on Ubunut any more, idk why
				# try the package "fonts-takao" or "ttf-takao" as mentioned here:
				# https://launchpad.net/takao-fonts
				x.path = "Noto Sans CJK JP Regular" # comes with Ubuntu
				x.size = 20
				x.add_alphabet :Latin
				x.add_alphabet :Japanese
			end
		
		@monospace_font = 
			RubyOF::TrueTypeFont.dsl_load do |x|
				x.path = "DejaVu Sans Mono"
				x.size = 20
				x.add_alphabet :Latin
			end
		
		
		
		
		
		
		update_text = "turn: "
		@turn_label =
			Text.new(@font, update_text).tap do |text|
				text.text_color = window.font_color
				
				text.body.p = CP::Vec2.new(43,1034)
			end
		
		@turn_number =
			Text.new(@monospace_font, "").tap do |text|
				text.text_color = window.font_color
				
				text.body.p = CP::Vec2.new(161,1034)
			end
		
		
		
		draw_text = "state: ???"
		@state_label =
			Text.new(@font, draw_text).tap do |text|
				text.text_color = window.font_color
				
				text.body.p = CP::Vec2.new(43,1113)
			end
		
		
		
		
		@state_display = Text.new(@monospace_font, "").tap do |text|
				text.text_color = window.font_color
				
				# text.body.p = CP::Vec2.new(285,337)
				text.body.p = CP::Vec2.new(383,937)
				# text.body.p = CP::Vec2.new(285,1137)
			end
		
		
		
		
		
		
		# UI can contain both world-space and screen-space elements
		
		
		# TODO: UI needs some way to draw entities to the screen. I need to be able to do spatial queries on these, for click events etc. However, they should not be tied to any one world state (the @wrapped_object, Body)
		
		# TODO: rename the live coding payload class, Body. Name is too similar to CP::Body, and it gets really confusing to think of the core code, and collision bodies in the same thought process.
		
		# TODO: pass camera to #update and #draw
			# update - so user can move the camera
			# draw   - so UI elements can be drawn world-relative
		# or maybe move actual draw logic into Camera class, to reduce code duplication? but then I need to figure out how the UI spaces and the Body spaces will both be passed into the Camera. 
		
		
		@screen_space.add @turn_label
		@screen_space.add @turn_number
		
		@screen_space.add @state_label
		
		@screen_space.add @state_display
		
		
		
	end
	
	def update(window, live, main, turn_number)
		
		# -- input handling
		parse_inputs(window, live, main, @input_queue)
		
		
		
		# -- manage visualization state
		puts "turn_number in current state: #{turn_number}"
		
		# @update_counter_label.print "update:"
		update_turn = turn_number.to_s.rjust(5, ' ')
		@turn_number.print update_turn
		
		
		# # state_text = "test"
		# state_text = 
		# 	window.live.instance_variable_get("@history")
		# 	.inspect
		# 	.each_char.each_slice(60)
		# 	.collect{|chunk| chunk.join("")}.join("\n")
		# 	# .inspect
		
		# state_text = "hello"
		
		# state_text = @fibers[:update].alive? ? "alive" : "dead"
		
		state_text = "state: #{window.live.state}"
		
		@state_label.print state_text
		
		
		
		
		@state_display.print "hello"
		# @state_display.print @fibers[:update].alive? ? "alive" : "dead"
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
	def draw(window, state, history, turn_number)
		# === Draw world relative
		window.camera.draw window.width, window.height do |bb|
			render_queue = Array.new
			
			@world_space.bb_query(bb) do |entity|
				render_queue << entity
			end
			
			# p @world_space
			# puts "render queue: #{render_queue.inspect}"
			
			# render_queue << @text
			
			# puts "render queue: #{render_queue.size}"
			
			
			# TODO: only sort the render queue when a new item is added, shaders are changed, textures are changed, or z index is changed, not every frame.
			
			# Render queue should sort by shader, then texture, then z depth [2]
			# (I may want to sort by z first, just because that feels more natural? Sorting by z last may occasionally cause errors. If you sort by z first, the user is always in control.)
			# 
			# [1]  https://www.gamedev.net/forums/topic/643277-game-engine-batch-rendering-advice/
			# [2]  http://lspiroengine.com/?p=96
			
			render_queue
			.group_by{ |e| e.texture }
			.each do |texture, same_texture|
				# next if texture.nil?
				
				texture.bind unless texture.nil?
				
				same_texture.each do |entity|
					entity.draw
				end
				
				texture.unbind unless texture.nil?
			end
			
			# TODO: set up transform hiearchy, with parents and children, in order to reduce the amount of work needed to compute positions / other transforms
				# (not really useful right now because everything is just translations, but perhaps useful later when rotations start kicking in.)
			
			
			
			# ASSUME: @font has not changed since data was created
				#  ^ if this assumption is broken, Text rendering may behave unpredictably
				#  ^ if you don't bind the texture, just get white squares
				
				
					# # @font.draw_string("From ruby: こんにちは", x, y)
					# @font.draw_string(data['channel-name'], x, y)
					# ofPopStyle()
					
					# # NOTE: to move string on z axis just use the normal ofTransform()
					# # src: https://forum.openframeworks.cc/t/is-there-any-means-to-draw-multibyte-string-in-3d/13838/4
			
		end
		# =======
		
		
		
		
		# === Draw screen relative
		# Render a bunch of different tasks
		# puts "screen space: #{@screen_space.entities.to_a.size}"
		
		@screen_space.entities.each
		.group_by{ |e| e.texture }
		.each do |texture, same_texture|
			# next if texture.nil?
			
			texture.bind unless texture.nil?
			
			same_texture.each do |entity|
				# puts "drawing entity"
				entity.draw
			end
			
			texture.unbind unless texture.nil?
		end
	end
	# TODO: change structure so this class has a state machine too, and both the state machine here and the one in Loader are kept in sync by some code in Loader
	
	
	
	def queue_input(timestamp, turn_number, method_name, args)
		input = InputData.new(timestamp, turn_number, method_name, args)
		@input_queue << input
	end
	
	private
	
	# turn raw inputs into input actions
	def parse_inputs(window, live, main, input_queue)
		# when main code execution stops, the turn counter stops incrementing. with the current setup, this means that all inputs past a certain time will have turn=100. this is why when trying to zoom in and out, you just zoom exponentially past a certain point.
		
		
		# @input_queue[@last_input..-1]
		p @input_queue
		@input_queue
		.select{ |input| input.turn_number == live.turn_number}
		.each do |input|
			self.send(
				input.method_message,
				window, live, main,
				input.turn_number,
				*input.args
			)
		end
		
		@last_input = @input_queue.length
		
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
				
				case live.state_name
				when :running
					puts "pausing..."
					live.pause
				when :paused
					puts "resuming..."
					live.resume
				end
				
			end
		when OF_KEY_LEFT
			# can't travel to t=0 ; the initial state is not renderable
			live.step_back
		when OF_KEY_RIGHT
			live.step_forward
		end
	end
	
	def key_released(window, live, main, turn_number, key)
		
	end
end
