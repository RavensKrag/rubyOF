Dir.chdir Pathname.new(__FILE__).dirname.expand_path do
	require './body_serialize.rb'
end

# NOTE: Don't do things based on Fiber state. It is unnecessary, and will not interact correctly with time travel modes. Use the state of the state machine instead.
# window.live.state => String
# window.live.state_name => Symbol


ONION_SKIN_OPACITY      = 0.73

ONION_SKIN_STANDARD_COLOR = RubyOF::Color.new.tap do |c|
	c.r, c.g, c.b, c.a = [0, 113, 188, (255*ONION_SKIN_OPACITY).to_i]
end
ONION_SKIN_NOW_COLOR = RubyOF::Color.new.tap do |c|
	c.r, c.g, c.b, c.a = [255, 255, 255, (255).to_i]
end
ONION_SKIN_FORECAST_COLOR = RubyOF::Color.new.tap do |c|
	c.r, c.g, c.b, c.a = [34, 181, 115, (255*ONION_SKIN_OPACITY).to_i]
end
ONION_SKIN_ERROR_COLOR = RubyOF::Color.new.tap do |c|
	c.r, c.g, c.b, c.a = [237, 28, 36, (255*ONION_SKIN_OPACITY).to_i]
end






class Body
	include RubyOF::Graphics 
	
	def initialize
		@fibers = Hash.new
		
		
		@world_space  = Space.new
		@screen_space = Space.new
	end
	
	
	def font_color=(color)
		@font_color = color
	end
	
	def regenerate_update_thread!
		@regenerate_update_thread = true
	end
	
	def regenerate_draw_thread!
		@regenerate_draw_thread = true
	end
	
	
	def update(window, turn_number)
		parse_input(window)
		
		
		@world_space.update
		@screen_space.update
		
		
		if @fibers[:update].nil? or @regenerate_update_thread
		@fibers[:update] = UpdateFiber.new do |on|
			on.turn 0 do
				@i = 0
				
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
				
				
				@text = Text.new(@font, "hello world こんにちわ")
				@text.text_color = @font_color
				
				# p @font_color
				
				# @text.body.p = @p.clone
				@text.body.p = CP::Vec2.new(160,600)
				
				@world_space.add @text
				
				
				# round-trip serialization test for Text entity
				# p @text
				# yaml = @text.to_yaml
				# puts yaml
				# p YAML.load yaml
				
				
				
				
				@i += 1
			end
			
			
			
			
			
			
			# prototype version 3 code first.
			# satify the following conditions:
			
			# v1, v2, and v3 run from t=1 -> t=10
			
			# there is a bifurcation between v1 and v3 @ t=4
				# qualitatively different behavior in spatial dynamics
				
			# there is a bifurcation between v1 and v2 @ t=8
				# in v2, code crashes the simulation -> error
				# in v1, code runs normally, reaching true ending @ t=10
			
			
			# (don't need to be able to visualze bifurcation points any time soon, but do need to see the alpha timeline. in Bret Victor's platforming example, you only want to see the path of your guy relative to the world, but sometimes in programming you don't know the goal: you only know what would be better relative to what youve seen. As such, you want to see how your new code compares to the old code - how the forecasted timeline compares to the alpha timeline)
			
			
			version = 1
			# version = 2
			# version = 3
			
			on.turn 1 do
				@i = 1
				@text.body.p = CP::Vec2.new(@i * 30,600)
			end
			on.turn 2 do
				@i = 2
				@text.body.p = CP::Vec2.new(@i * 30,600)
			end
			on.turn 3 do
				@i = 3
				@text.body.p = CP::Vec2.new(@i * 30,600)
			end
			
			case version
			when 1
			# 1) original timeline - linear movement
			on.turn 4 do
				@i = 4
				@text.body.p = CP::Vec2.new(@i * 70,600)
			end
			on.turn 5 do
				@i = 5
				@text.body.p = CP::Vec2.new(@i * 70,600)
			end
			on.turn 6 do
				@i = 6
				@text.body.p = CP::Vec2.new(@i * 70,600)
			end
			on.turn 7 do
				@i = 7
				@text.body.p = CP::Vec2.new(@i * 70,600)
			end
			on.turn 8 do
				@i = 8
				@text.body.p = CP::Vec2.new(@i * 70,600)
			end
			on.turn 9 do
				@i = 9
				@text.body.p = CP::Vec2.new(@i * 70,600)
			end
			on.turn 10 do
				@i = 10
				@text.body.p = CP::Vec2.new(@i * 70,600)
			end
			
			
			
			when 2
			# 2) error to stop execution and get to paradox timeline
			#    (should show *some* progress)
			on.turn 4 do
				@text.body.p = CP::Vec2.new(120,600)
			end
			on.turn 5 do
				@text.body.p = CP::Vec2.new(200,600)
			end
			on.turn 6 do
				@text.body.p = CP::Vec2.new(400,600)
			end
			on.turn 7 do
				@text.body.p = CP::Vec2.new(800,600)
			end
			on.turn 8 do
				@text.body.p = CP::Vec2.new(1000,600)
			end
			on.turn 9 do
				raise "BAIL OUT!!"
			end
			
				
			when 3
			# 3) fixed timeline - exponential movement
			on.turn 4 do
				@text.body.p = CP::Vec2.new(120,600)
			end
			on.turn 5 do
				@text.body.p = CP::Vec2.new(200,600)
			end
			on.turn 6 do
				@text.body.p = CP::Vec2.new(400,600)
			end
			on.turn 7 do
				@text.body.p = CP::Vec2.new(800,600)
			end
			on.turn 8 do
				@text.body.p = CP::Vec2.new(1000,600)
			end
			on.turn 9 do
				@text.body.p = CP::Vec2.new(1200,600)
			end
			on.turn 10 do
				@text.body.p = CP::Vec2.new(1200,600) # can't forecast 10
				# (maybe need to save the current state before forecasting???)
				# FIXME: fix off-by-one error on forecasting
			end
			
			
			
			end
			
			
			on.turn 11..100 do
				# NO-OP
			end
			
			
			
		end
		@regenerate_update_thread = false
		end
		
		
		# This must be last, so the yield from the fiber can return to Loader.
		# But if the UI code executes before turn 0, then nothing will render.
		# TODO: consider separate method for UI code.
		out = @fibers[:update].update turn_number
		
		puts "#{turn_number} => #{out}"
		
		turn_number += 1
		
		
		return out
	end
	
	def draw(window, turn_number)
		# puts "  drawing..."
		
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
	
	def on_exit(window)
		
	end
	
	
	# NOTE: serialization uses YAML, and is written in body_serialize.rb
	
	
	
	
	
	
	def queue_input(input_data)
		@input_queue   ||= Array.new
		@input_queue_i ||= 0 # entries @ index >= i have not yet been processed
		@input_queue << input_data
		
		# p @input_queue
	end
	
	# FIXME: extra inputs are being queued up while time traveling
		# NO - it's actually even worse - we can't enter time traveling mode right now, because we're not actually processing the inputs. we're just queuing them up. The code to trigger the "pause" event when the spacebar is pressed is in this file, and it is not currently being called.
		
		# now I can pause state, but I can't move through time, because #update is not being called on the state, and that is what let's me parse inputs. so I need to restructure something, to allow for this to work.
		
	# FIXME: very many text entities are being created, and it is bogging down the system
	def parse_input(window)
		return if @input_queue.nil?
		
		
		
		# NOTE: ruby 2.6 will have "endless ranges" which allows for the following syntax: @input_queue[1..]
		# however, as of 2018.8.25, ruby 2.6 has not yet been released
			# https://medium.com/square-corner-blog/rubys-new-infinite-range-syntax-0-97777cf06270
			# https://blog.bigbinary.com/2018/07/04/ruby-2-6-adds-endless-range.html
			# https://bugs.ruby-lang.org/issues/12912
		
		# Associate input data with index in the input queue, not the index in the list of unprocessed items
		@input_queue.each_with_index
		.to_a[@input_queue_i..-1]
		.each do |input_data, i|
			timestamp_in_ms, turn_number, method_message, args = input_data
			
			
			# # -- visualize the inputs
			# input = Text.new(@font, i.to_s)
			# input.body.p = CP::Vec2.new(i * 20, 600)
			
			# input.text_color = RubyOF::Color.new.tap do |c|
			# 	c.r, c.g, c.b, c.a = [255, 0, 0, 255]
			# end
			
			
			
			# @screen_space.add input
			
			
			# -- actually deal with the input
			# TODO: send timestamp and turn number as well
			p args
			self.send method_message, window, *args
		end
		
		# move the index to the end
		# NOTE: ary[ary.length..-1] => []
		@input_queue_i = @input_queue.length
	end
	
	
	# I want to visualize inputs happening over time, so I can see what the actualy input signals I'm dealing with are. I need to measure time in both ms and turn count. I also need to see how spatial input (ie, mouse input) relate to the spatial component of data (time and space are linked).
	
	# I want interface code to be able to interact with spatial entities. How would I reference them by name? Variable names? Entity tags (like HTML ID)? Should I always first accquire entities through a spatial query (raycast?).
	
	def mouse_moved(window, x,y)
		@p = [x,y]
	end
	
	def mouse_pressed(window, x,y, button)
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
	
	def mouse_dragged(window, x,y, button)
		# super(x,y, button)
		
		case button
			when OF_MOUSE_BUTTON_2 # middle click
				pt = CP::Vec2.new(x,y)
				d = (pt - @drag_origin)/window.camera.zoom
				window.camera.pos = d + @camera_origin
		end
	end
	
	def mouse_released(window, x,y, button)
		# super(x,y, button)
		
		case button
			when OF_MOUSE_BUTTON_2 # middle click
				
		end
	end
	
	def mouse_scrolled(window, x,y, scrollX, scrollY)
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
	
	
	
	def key_pressed(window, key)
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
	
	def key_released(window, key)
		
	end
	
	
end
