Dir.chdir Pathname.new(__FILE__).dirname.expand_path do
	require './body_serialize.rb'
end

# NOTE: Don't do things based on Fiber state. It is unnecessary, and will not interact correctly with time travel modes. Use the state of the state machine instead.
# window.live.state => String
# window.live.state_name => Symbol


ONION_SKIN_OPACITY      = 0.7

ONION_SKIN_BEFORE_COLOR = RubyOF::Color.new.tap do |c|
	c.r, c.g, c.b, c.a = [0, 0, 255, (255*ONION_SKIN_OPACITY).to_i]
end
ONION_SKIN_NOW_COLOR = RubyOF::Color.new.tap do |c|
	c.r, c.g, c.b, c.a = [255, 255, 255, (255).to_i]
end
ONION_SKIN_AFTER_COLOR = RubyOF::Color.new.tap do |c|
	c.r, c.g, c.b, c.a = [0, 0, 255, (255*ONION_SKIN_OPACITY).to_i]
end


class Body
	include RubyOF::Graphics 
	
	def font_color=(color)
		@font_color = color
	end
	
	def regenerate_update_thread!
		@regenerate_update_thread = true
	end
	
	def regenerate_draw_thread!
		@regenerate_draw_thread = true
	end
	
	
	def update(window)
		if @fibers[:update].nil? or @regenerate_update_thread
		@fibers[:update] = Fiber.new do |on|
			on.turn 0 do
				@i = 0
				
				@camera = Camera.new(window.width/2, window.height/2)
				
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
				# @text.body.p = CP::Vec2.new(0,0)
				
				# @text.texture.bind
				# @text.draw
				
				
				
				# round-trip serialization test for Text entity
				# p @text
				# yaml = @text.to_yaml
				# puts yaml
				# p YAML.load yaml
				
				
				
				
				@i += 1
			end
			
			on.turn 1..9 do
				puts "  updating..."
				# if i > 20
				# 	raise "DERP"
				# end
				@i += 1
				# puts @i
				
				@text.body.p = CP::Vec2.new(@i * 100,600)
			end
			
			on.turn 100 do
				puts "END OF PROGRAM"
			end
			
			
			# When you reach the end of update tasks, tell the surrounding system to pause further execution. If no more updates are being made, then no new frames need to be rendered, right? Can just render the old state.
				# This is not completely true, as the user can still make changes based on direct manipulation. But those changes should generate new state, so hopefully this is all fine?
				# Soon, will need to consider how direct input effects the time traveling paradigm.
			Fiber.yield :end
			# (tell Loader to transition to "true ending" state)
		end
		@regenerate_update_thread = false
		end
		
		
		@fibers[:update].resume @update_counter
	end
	
	def draw(window)
		if @fibers[:draw].nil? or @regenerate_draw_thread
		@fibers[:draw] = Fiber.new do |on|		
		loop do
			# puts "  drawing..."
			
			# === Draw world relative
			@camera.draw window.width, window.height do |bb|
				render_queue = Array.new
				
				# @space.bb_query(bb) do |entity|
				# 	render_queue << entity
				# end
				render_queue << @text
				
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
			Array.new.tap{ |queue|
				update_text = "update:"
				@update_counter_label =
					Text.new(@font, update_text).tap do |text|
						text.text_color = @font_color
						
						text.body.p = CP::Vec2.new(43,1034)
					end
				
				number = @update_counter.current_turn.to_s.rjust(5, ' ')
				@update_counter_number =
					Text.new(@monospace_font, number).tap do |text|
						text.text_color = @font_color
						
						text.body.p = CP::Vec2.new(161,1034)
					end
				
				
				draw_text = "draw:"
				@draw_counter_label =
					Text.new(@font, draw_text).tap do |text|
						text.text_color = @font_color
						
						text.body.p = CP::Vec2.new(43,1069)
					end
					
				number = @draw_counter.current_turn.to_s.rjust(5, ' ')
				@draw_counter_number =
					Text.new(@monospace_font, number).tap do |text|
						text.text_color = @font_color
						
						text.body.p = CP::Vec2.new(161,1069)
					end
				
				
				draw_text = "state: #{window.live.state}"
				@state_label =
					Text.new(@font, draw_text).tap do |text|
						text.text_color = @font_color
						
						text.body.p = CP::Vec2.new(43,1113)
					end
				
				
				
				
				# # state_text = "test"
				# state_text = 
				# 	window.live.instance_variable_get("@history")
				# 	.inspect
				# 	.each_char.each_slice(60)
				# 	.collect{|chunk| chunk.join("")}.join("\n")
				# 	# .inspect
				
				state_text = "hello"
				
				# state_text = @fibers[:update].alive? ? "alive" : "dead"
				
				@state_display = Text.new(@monospace_font, state_text).tap do |text|
						text.text_color = @font_color
						
						# text.body.p = CP::Vec2.new(285,337)
						text.body.p = CP::Vec2.new(383,937)
						# text.body.p = CP::Vec2.new(285,1137)
					end
				
				
				
				
				queue << @update_counter_label
				queue << @update_counter_number
				queue << @draw_counter_label
				queue << @draw_counter_number
				
				
				queue << @state_label
				
				queue << @state_display
			}
			.group_by{ |e| e.texture }
			.each do |texture, same_texture|
				# next if texture.nil?
				
				texture.bind unless texture.nil?
				
				same_texture.each do |entity|
					entity.draw
				end
				
				texture.unbind unless texture.nil?
			end
			
			
			
			
			# TODO: only render the task if it is still alive (allow for non-looping tasks)
			# =======
			
			
			
			
			Fiber.yield
		end
		end
		@regenerate_draw_thread = false
		end
		
		
		@fibers[:draw].resume @draw_counter
	end
	
	def on_exit(window)
		
	end
	
	
	# NOTE: serialization uses YAML, and is written in body_serialize.rb
	
	
	
	
	
	
	
	
	
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
				@camera_origin = @camera.pos.clone
		end
	end
	
	def mouse_dragged(window, x,y, button)
		# super(x,y, button)
		
		case button
			when OF_MOUSE_BUTTON_2 # middle click
				pt = CP::Vec2.new(x,y)
				d = (pt - @drag_origin)/@camera.zoom
				@camera.pos = d + @camera_origin
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
			@camera.zoom *= zoom_factor
		elsif scrollY < 0
			@camera.zoom /= zoom_factor
		else
			
		end
		
		puts "camera zoom: #{@camera.zoom}"
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
