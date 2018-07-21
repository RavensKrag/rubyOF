# (create instance of Object class, and define things on it's singleton class)
->(){ obj = Object.new; class << obj
	include RubyOF::Graphics
	
	
	include LiveCoding::InspectionMixin
	
	def setup(window, save_directory)
		# TODO: need to be able to pass data into the 'constructor' of the object.
			# When you do: LiveCoding::DynamicObject.new
			# there needs to be a way to pass data in,
			# and then that data needs to wind up in this block.
			# That would allow for doing things like allocating
			# fonts in one place, and then passing them around.
		
		
		@window = window
		
		
		puts "setting up callback object #{self.class.inspect}"
		
		@fonts = {
			'Takao P Gothic' => RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
				x.size = 20
				x.add_alphabet :Latin
				x.add_alphabet :Japanese
				
				# TODO: how do you discover what the alphabets are?
				# stored in RubyOF::TtfSettings::UnicodeRanges
				# maybe provide discoverable access through #alphabets on the DSL object?
			end,
			
			'DejaVu Sans Mono' => RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
				x.size = 20
				x.add_alphabet :Latin
			end
		}
		
		# TODO: store fonts in a centralized asset manager, but use WeakRef such that the items in the asset manager will only be present as long as there is at least one other reference elsewhere (Ruby-style memory managament. Maybe could be swapped out for C++ level memory management in a transparent way?)
		
		@string_out   = TextEntity.new(@window, @fonts['DejaVu Sans Mono'])
		@string_out.p = CP::Vec2.new 0, 0
		
		@string_out.string = "fps test"
		
		
		@time = Timer.new
		
		
		@fps_history = Array.new
		@max_buffer_size = 300
	end
	
	# save the state of the object (dump state)
	# 
	# Should return a Plain-Old Ruby Object
	# (likely Array or Hash as the outer container)
	# (basically, something that could be trivially saved as YAML)
	def serialize(save_directory)
		
	end
	
	# reverse all the stateful changes made to @window
	# (basically, undo everything you did across all ticks of #update and #draw)
	# Usually, this is just about deleting the
	# entities you created and put in the space.
	def cleanup
		
	end
	
	# TODO: figure out if there needs to be a "redo" operation as well
	# (easy enough - just save the data in this object instead of full on deleting it. That way, if this object is cleared, the state will be fully gone, but as long as you have this object, you can roll backwards and forwards at will.)
	
	
	def update
		# TODO: add framerate calculation to Timer class
		
		@fps_history << @window.ofGetFrameRate.round(5)
		if @fps_history.length > @max_buffer_size
			@fps_history.shift # remove the first element
		end
		
		# check to make sure the buffer is now under the limit.
		# if it has gone over, need to raise an error of some sort.
		if @fps_history.length > @max_buffer_size
			raise "fps history buffer saturated"
		end
	end
	
	def draw
		r = 2
		h = 100
		
		
		x,y = [50,@window.height - h - @string_out.font.line_height]
		z = 1
		ofPushMatrix()
		ofTranslate(x,y,z)
		# ^ NOTE: This isn't supposed to accept a block, but if you give it one, it doesn't complain. That's very weird...
			# oh weird. that's just normal behavior for ruby. huh.
			# ex)
				# def foo(x,y)
				#   p [x,y]
				# end
				
				# foo 1,2 {puts "hello"}
				# => [1,2]
				# # (no problems)
		
		ofPushStyle()
			
			bg_color =
				RubyOF::Color.new.tap do |c|
					c.r, c.g, c.b, c.a = [0, 141, 240, 255]
				end
			ofSetColor(bg_color)
			
			
			x,y = [0,0]
			z = 0
			w = r*@max_buffer_size
			ofDrawRectangle(x,y,z, w,h)
		ofPopStyle()
		
		@fps_history.each_with_index do |fps, i|
			x = i * 2
			y = 100 - fps
			
			ofDrawCircle(x,y,0, r)
		end
		
		@string_out.draw
		
		
		
		
		ofPopMatrix()
		
	end
	
	
	
	
	# TODO: consider adding additional callbacks for input / output connections to other computational units (this is for when you have a full graph setup to throw data around in this newfangled system)
	
	# TODO: at that point, you need to be able to write code for those nodes in C++ as well, so the anonymous classes created in this file, etc, must be subclasses of some kind of C++ type (maybe even some sort of weak ref / smart pointer that allows for C++ memory allocation? (pooled memory?))
	
	
	# send data to another live coding module in memory
	# (for planned visual coding graph)
	# NOTE: Try not to leak state (send immutable data, functional style)
	def send_data
		
	end
	
	# recive data from another live-coding module in memory
	# (for planned visual coding graph)
	def recieve_data(points)
		
	end
	
	
end; return obj }

