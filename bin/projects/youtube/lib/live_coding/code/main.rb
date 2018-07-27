# (create instance of Object class, and define things on it's singleton class)
->(){ obj = Object.new; class << obj

gem_root = Pathname.new(__FILE__).expand_path.dirname.parent.parent.parent.parent.parent.parent

require 'yaml'
require (gem_root/'lib'/'rubyOF'/'monkey_patches'/'chipmunk'/'vec2').to_s

	
	# ===================================
	
	
	include LiveCoding::InspectionMixin
	
	include RubyOF::Graphics
	
	
	
	def setup(window, save_directory, parameters)
		@window = window
		
		root = Pathname.new(__FILE__).expand_path.dirname.parent.parent.parent
		
		@space, @font = *parameters
		
		
		# # str = "screen text: hello world!"
		
		text = "hey"
		@text = Text.new(@font, "screen text: #{text}")
		@text.body.p = CP::Vec2.new(660,100)
		
		
		@text.update
		# @text.update # force an update, because we are already in #draw phase
		# # (if you don't force the update, when system attempts to draw this text entity, it will fail, because the mesh has not yet been created.)
		
		
		# @space.add @text
		
		
		
		@font_monospace = 
			RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "DejaVu Sans Mono"
				x.size = 20
				x.add_alphabet :Latin
				# x.add_alphabet :Japanese
			end
		
		
		@mouse_sample_rate = 60
		
		@mouse_history = 
			(30 * @mouse_sample_rate)
			.times.collect{|x| CP::Vec2.new(0,0) }
		
		@mouse_trackers = 30.times.collect{|i| Text.new(@font, "m#{i}") }
		@mouse_trackers.each do |mouse_tag|
			mouse_tag.update()
			@space.add mouse_tag
		end
	end
	
	# save the state of the object (dump state)
	# 
	# Should return a Plain-Old Ruby Object
	# (likely Array or Hash as the outer container)
	# (basically, something that could be trivially saved as YAML)
	def serialize(save_directory)
		# [
		# 	# @live_wrapper,
		# 	@input_test,
		# ].each do |dynamic_obj|
		# 	dynamic_obj.serialize save_directory
		# end
	end
	
	# reverse all the stateful changes made to @window
	# (basically, undo everything you did across all ticks of #update and #draw)
	# Usually, this is just about deleting the
	# entities you created and put in the space.
	def cleanup
		@space.delete @text
		
		@mouse_trackers.each do |entity|
			@space.delete entity
		end
	end
	
	# TODO: figure out if there needs to be a "redo" operation as well
	# (easy enough - just save the data in this object instead of full on deleting it. That way, if this object is cleared, the state will be fully gone, but as long as you have this object, you can roll backwards and forwards at will.)
	
	
	def update
		# if @mouse_history.length > 1
		# 	@mouse_history.pop
		# end
		
		@mouse_history.reverse_each.each_with_index do |point, i|
			entity = @mouse_trackers[i / @mouse_sample_rate]
			entity.body.p = point
		end
		
		# puts @mouse_history.collect{|x| x.to_s }.join(' ')
		
		
		
		unless @mouse_text.nil?
			text = @mouse_text.shape.bb.t.inspect 
			text += "#{@window.width}  => #{@mouse_text.shape.bb.t  >  @window.width}"
			
			# add linebreaks
			text = text.each_char.each_slice(70).collect{|x| x.join }.join("\n")
			
			@text = Text.new(@font_monospace, "debug out:\n #{text}")
			@text.body.p = CP::Vec2.new(-1100,100)
			
			
			@text.update # force an update, because we are already in #draw phase
			# (if you don't force the update, when system attempts to draw this text entity, it will fail, because the mesh has not yet been created.)
		end
		
		
		# @text.string = "test"
		# @text.update
		#%^ note: currently now way to change the string on an existing Text entity. That would require regenerating a lot of data, but I should look into making a way to actually do it.
		
		
		# data = @input_test.send_data
		# @live_wrapper.recieve_data data
		
		# puts "hello world"
		# puts @mouse
		# puts @mouse
		unless @mouse.nil?
			# @text.body.p = @mouse 
		end
		
		# p @text
		# p @space.methods
		# p @space.entities.collect{|x| x.class }
	end
	
	def draw(window, camera)
		# === Draw world relative
		camera.draw window.width, window.height do |bb|
			render_queue = Array.new
			
			@space.bb_query(bb) do |entity|
				render_queue << entity
			end
			
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
			
			
			@text.texture.bind
			@text.draw()
		end
		# =======
		
		
		# === Draw screen relative
		# Render a bunch of different tasks
		
		# TODO: only render the task if it is still alive (allow for non-looping tasks)
		
		
		
		unless @mouse.nil?
			@mouse_text = Text.new(@font, @mouse.to_s)
			@mouse_text.update
			
			@mouse_text.body.p = @mouse
			
			# display text near mouse pointer,
			# but offset so it doesn't go off the screen
			offset = CP::Vec2.new(0,0)
			
			top_margin = 50
			kickback = 20
			
			if @mouse_text.shape.bb.r > @window.width
				offset.x = -(@mouse_text.shape.bb.r - @window.width)
			end
			if @mouse_text.shape.bb.b < top_margin
				offset.y = (top_margin - @mouse_text.shape.bb.b)
			end
			
			@mouse_text.body.p = @mouse + offset
			
			
			@mouse_text.texture.bind
			@mouse_text.draw
		end
		
		
		# @draw_debug_ui.resume
		# @draw_color_picker.resume
		# =======
	end
	
	
	
	
	# TODO: consider adding additional callbacks for input / output connections to other computational units (this is for when you have a full graph setup to throw data around in this newfangled system)
	
	# TODO: at that point, you need to be able to write code for those nodes in C++ as well, so the anonymous classes created in this file, etc, must be subclasses of some kind of C++ type (maybe even some sort of weak ref / smart pointer that allows for C++ memory allocation? (pooled memory?))
	
	
	# NOTE: Can't use the name 'send' because the #send method is what allows you to call arbitrary methods using Ruby's message passing interface.
	# 
	# # send data to another live coding module in memory
	# # (for planned visual coding graph)
	# # NOTE: Try not to leak state (send immutable data, functional style)
	# def send
	# 	return nil
	# end
	
	# # recive data from another live-coding module in memory
	# # (for planned visual coding graph)
	# def recieve(data)
		
	# end
	
	
	def mouse_moved(x,y)
		# [
		# 	# @live_wrapper,
		# 	@input_test,
		# ].each do |dynamic_obj|
		# 	dynamic_obj.mouse_moved x,y
		# end
		
		@mouse = CP::Vec2.new(x,y)
		
		x = @mouse_history.shift
		x = @mouse
		@mouse_history.push x
	end
	
	def mouse_pressed(x,y, button)
		# [
		# 	# @live_wrapper,
		# 	@input_test,
		# ].each do |dynamic_obj|
		# 	dynamic_obj.mouse_pressed x,y, button
		# end
	end
	
	def mouse_released(x,y, button)
		# [
		# 	# @live_wrapper,
		# 	@input_test,
		# ].each do |dynamic_obj|
		# 	dynamic_obj.mouse_released x,y, button
		# end
	end
	
	def mouse_dragged(x,y, button)
		# [
		# 	# @live_wrapper,
		# 	@input_test,
		# ].each do |dynamic_obj|
		# 	dynamic_obj.mouse_dragged x,y, button
		# end
	end
	
end; return obj }

