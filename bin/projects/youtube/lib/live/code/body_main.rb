class Body
	def font_color=(color)
		@font_color = color
	end
	
	
	def update(window)
		@camera ||= Camera.new(window.width/2, window.height/2)
		
		@i ||= 0
		
		@font ||= 
			RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
				x.size = 20
				x.add_alphabet :Latin
				x.add_alphabet :Japanese
			end
		
		@fibers[:update] ||= Fiber.new do |on|
			on.turn 0 do
				@text = Text.new(@font, "hello world")
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
			
			# on.turn 100 do
			# 	raise "END OF PROGRAM"
			# end
			
			# NOTE: Don't use Fiber.yield inside turn() block. turn() already implicitly calls yield. Calling Fiber.yield again will result in the Fiber only running every other tick.
			loop do
				
				Fiber.yield
			end
		end
		
		@fibers[:update].resume @update_counter
	end
	
	def draw(window, status)
		@fibers[:draw] ||= Fiber.new do |on|		
		loop do
			puts "  drawing..."
			
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
			
			# TODO: only render the task if it is still alive (allow for non-looping tasks)
			
			
			
			
			
			Fiber.yield
		end
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
