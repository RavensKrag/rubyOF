# (create instance of Object class, and define things on it's singleton class)
->(){ obj = Object.new; class << obj
	include LiveCoding::InspectionMixin
	
	include RubyOF::Graphics
	
	def setup(window, save_directory)
		# basic initialization
		@window = window
		
		@click_log = Array.new
		
		@color = RubyOF::Color.new.tap do |c|
			c.r, c.g, c.b, c.a = [0, 141, 240, 255]
		end
		
		
		# load data from disk
		filepath = save_directory/'mouse_data.yaml'
		if filepath.exist?
			File.open(filepath, 'r') do |f| 
				data = YAML.load(f)
				data.each do |type, *args|
					case type
						
					when 'point'
						@click_log << CP::Vec2.new(*args)
					else
						raise "ERROR: Unexpected type in serialization"
					end
				end
			end
		end
	end
	
	# save the state of the object (dump state)
	# 
	# Should return a Plain-Old Ruby Object
	# (likely Array or Hash as the outer container)
	# (basically, something that could be trivially saved as YAML)
	def serialize(save_directory)
		filepath = save_directory/'mouse_data.yaml'
		File.open(filepath, 'w') do |f|
			
			
			data = @click_log.collect{|point|  ['point'] + point.to_a}
			f.print YAML.dump(data)
		end
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
		
	end
	
	def draw
		@click_log.each do |point|
			ofPushStyle()
			ofSetColor(@color)
			
			
			x,y = point.to_a
			z = 0
			r = 5
			ofDrawCircle(x,y,z, r)
			
			
			ofPopStyle()
		end
		
		# if you have enough points to try and construct a rectangle,
		# go ahead and draw a rectangle
		if @click_log.length >= 4
			a = @click_log[0]
			b = @click_log[1]
			
			x1, y1 = a.to_a
			x2, y2 = b.to_a
			
			z = 0
			ofDrawLine(
				x1, y1, z, 
				x2, y2, z
			)
		end
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
		p [x,y]
	end
	
	def mouse_pressed(x,y, button)
		case button
			when 0 # left
				@click_log << CP::Vec2.new(x,y)
			when 1 # middle
				
			when 2 # right
				
			when 3 # prev (extra mouse button)
					
			when 4 # next (extra mouse button)
				
		end
		
	end
	
	def mouse_released(x,y, button)
		
	end
	
	def mouse_dragged(x,y, button)
		
	end
	
end; return obj }

