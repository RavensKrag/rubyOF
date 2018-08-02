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
					RubyOF::TrueTypeFont.new.dsl_load do |x|
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
					RubyOF::TrueTypeFont.new.dsl_load do |x|
						x.path = "DejaVu Sans Mono"
						x.size = 20
						x.add_alphabet :Latin
					end
				
				
				@text = Text.new(@font, "hello world こんにちわ")
				@text.text_color = @font_color
				
				# p @font_color
				
				@text.update
				
				# @text.body.p = @p.clone
				@text.body.p = CP::Vec2.new(560,600)
				# @text.body.p = CP::Vec2.new(0,0)
				
				# @text.texture.bind
				# @text.draw
				
				
				
				@i += 1
			end
			
			on.turn 1..9 do
				puts "  updating..."
				# if i > 20
				# 	raise "DERP"
				# end
				@i += 1
				# puts @i
			end
			
			on.turn 100 do
				puts "END OF PROGRAM"
			end
			
			
			# When you reach the end of update tasks, tell the surrounding system to pause further execution. If no more updates are being made, then no new frames need to be rendered, right? Can just render the old state.
				# This is not completely true, as the user can still make changes based on direct manipulation. But those changes should generate new state, so hopefully this is all fine?
				# Soon, will need to consider how direct input effects the time traveling paradigm.
			Fiber.yield :end
			# (currently, 'pause' state still renders new frames, so this works fine)
		end
		@regenerate_update_thread = false
		end
		
		
		@fibers[:update].resume @update_counter
	end
	
	def draw(window, status)
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
						text.update
						
						text.body.p = CP::Vec2.new(43,1034)
					end
				
				number = @update_counter.current_turn.to_s.rjust(5, ' ')
				@update_counter_number =
					Text.new(@monospace_font, number).tap do |text|
						text.text_color = @font_color
						text.update
						
						text.body.p = CP::Vec2.new(161,1034)
					end
				
				
				
				draw_text = "draw:"
				@draw_counter_label =
					Text.new(@font, draw_text).tap do |text|
						text.text_color = @font_color
						text.update
						
						text.body.p = CP::Vec2.new(43,1069)
					end
					
				number = @draw_counter.current_turn.to_s.rjust(5, ' ')
				@draw_counter_number =
					Text.new(@monospace_font, number).tap do |text|
						text.text_color = @font_color
						text.update
						
						text.body.p = CP::Vec2.new(161,1069)
					end
				
				
				draw_text = "state: #{window.live.state}"
				@state_label =
					Text.new(@font, draw_text).tap do |text|
						text.text_color = @font_color
						text.update
						
						text.body.p = CP::Vec2.new(43,1113)
					end
				
				
				
				
				queue << @update_counter_label
				queue << @update_counter_number
				queue << @draw_counter_label
				queue << @draw_counter_number
				
				queue << @state_label
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
	
	def on_exit
		
	end
	
	# save the entire state of the world.
	# return the result, don't output to file here.
	def save
		puts "    saving, in body"
		
		out = Hash.new
		
		
		var_names = 
			self.instance_variables
			.reject{|x| x.to_s.include? '@fibers' }
									
		var_values = var_names.collect{|x| self.instance_variable_get x }
		
		out[:instance_vars] = var_names.zip(var_values).to_h
		
		
		
		return out
	end
	
	# restore from saved data
	def load(data)
		
	end
	
	
	class << self
		def from_data(data)
			obj = self.new
			obj.load(data)
			
			return obj
		end
	end
	
	
	
	
	
	
	
	
	
	
	def mouse_moved(x,y)
		@p = [x,y]
	end
	
	def mouse_pressed(x,y, button)
		puts "moving mouse"
		# super(x,y, button)
		
		# ofExit() if button == 8
		# # different window systems return different numbers
		# # for the 'forward' mouse button:
		# 	# GLFW: 4
		# 	# Glut: 8
		# # TODO: set button codes as constants?
		
		case button
			when 1 # middle click
				@drag_origin = CP::Vec2.new(x,y)
				@camera_origin = @camera.pos.clone
		end
	end
	
	def mouse_dragged(x,y, button)
		# super(x,y, button)
		
		case button
			when 1 # middle click
				pt = CP::Vec2.new(x,y)
				d = (pt - @drag_origin)/@camera.zoom
				@camera.pos = d + @camera_origin
		end
	end
	
	def mouse_released(x,y, button)
		# super(x,y, button)
		
		case button
			when 1 # middle click
				
		end
	end
	
	def mouse_scrolled(x,y, scrollX, scrollY)
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
	
end
