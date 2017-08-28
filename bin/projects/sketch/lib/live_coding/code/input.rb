# (create instance of Object class, and define things on it's singleton class)
->(){ obj = Object.new; class << obj

require Pathname.new(__FILE__).expand_path.dirname/'entities.rb'

class SpatialDB
	def initialize(save_directory)
		@testing = false
		
		@db =
			if @testing
				# connect to test DB in memory
				Sequel.sqlite
			else
				# connect to real DB on the disk
				# path = save_directory/'spatial_data.db'
				
				path = save_directory/'test-2.3.sqlite' # data for tutorial
				
				puts path
				
				Sequel.connect("sqlite://#{path}")
			end
		
		# load spatialite
		@db.run "SELECT load_extension('mod_spatialite');"
		
		
		
		
		# @db.fetch "SELECT * FROM towns LIMIT 5;"
		
		# @db.fetch "SELECT name, peoples, AsText(Geometry) from Towns where peoples > 350000 order by peoples DESC;"
		# # REPL.connect(binding)
		
		
		
		# "the SpatiaLite X() function returns the X coordinate for a POINT.
		# the Y() function returns the Y coordinate for a POINT.""
		# ^ source: https://www.gaia-gis.it/gaia-sins/spatialite-tutorial-2.3.1.html
		
		x = @db.fetch "SELECT name, peoples, X(Geometry), Y(Geometry) from Towns where peoples > 350000 order by peoples DESC;"
		puts x.all # need to use #all to execute the DataSet and get a Hash
		
		x.all[0].tap do |point|
			x = point["X(Geometry)".to_sym]
			y = point["Y(Geometry)".to_sym]
			
			p [x,y]
			
			puts CP::Vec2.new(x,y)
		end
		
		
		# "the BEGIN and COMMIT SQL statements defines a transaction; a single transaction is intended to define an atomic operation.""
		
	end
	
	
	def test_query
		x = @db.fetch "SELECT name, peoples, X(Geometry), Y(Geometry) from Towns where peoples > 350000 order by peoples DESC;"
		x.all # need to use #all to execute the DataSet and get a Hash
	end
end

class PointData
	attr_accessor :color
	
	def initialize(z, render_radius)
		@z = z
		# z index for rendering the vert visualization
		
		@render_radius = render_radius
		# render radius of the circle that represents the point
		
		# ---
		
		@space = CP::Space.new # for spatially organizing data
		@dt = 1/60.0
		
		@points = Array.new # raw data, CP::Vec2 instances
		
		
		# color to draw the points in 
		@color = RubyOF::Color.new.tap do |c|
			c.r, c.g, c.b, c.a = [0, 141, 240, 255]
		end
	end
	
	def serialize(save_directory)
		filepath = save_directory/'mouse_data.yaml'
		File.open(filepath, 'w') do |f|
			# TODO: data from mouse manipulations needs to make it back to the disk eventually. Currently only serializing the backend data over and over again.
			
			data = self.to_a.collect{|point|  ['point'] + point.to_a}
			f.print YAML.dump(data)
		end
	end
	
	def update
		@space.step @dt
	end
	
	def draw(window, font)
		window.ofPushStyle()
		window.ofSetColor(@color)
		
		r = @render_radius
		
		# @points.each_with_index do |vec, i|
		
		points  = self.to_a
		
		points
		.each_with_index do |vec, i|
			# -- render the actual point data
			window.ofDrawCircle(vec.x, vec.y, @z, r)
			
			
			
			# -- render the index of each point, above where the point is
			char_to_px = 18 # string width to horiz displacement 
			
			label = i.to_s
			width  = font.string_width(label)
			
			# NOTE: strings appear to draw from the bottom left corner
			font.draw_string(
				i.to_s,
				
				vec.x - (width) / 2,
				vec.y - r*2 # neg y is up the screen
			)
			
		end
		
		window.ofPopStyle()
		
		
		
		# if you have enough points to try and construct a rectangle,
		# go ahead and draw a rectangle
		if points.length >= 4
			a = points[0]
			b = points[1]
			
			x1, y1 = a.to_a
			x2, y2 = b.to_a
			
			z = @z
			window.ofDrawLine(
				x1, y1, z, 
				x2, y2, z
			)
		end
	end
	
	
	def add(vec)
		@points << vec
		
		
		# backend radius
		r = 1/2.0 - 0.001
		#   representing points in space as small circles
		#   Each circle has diameter 1 (because each is 1 px)
		#   but just in case, the diameter is made slightly smaller than that
		# (the mouse query uses a larger radius, so it's easy to click on things)
		
		body  = CP::Body.new(1,1)
		shape = CP::Shape::Circle.new(body, r)
		
		
		# Need to set body position, or else you get the default
		# (not sure what that is.. likely the origin?)
		body.p = vec
		
		# bind raw data to the graphical representation
		# (this way, you can get the raw data back on Space callbacks)
		shape.object = vec
		
		# add both body and shape to the simulation space
		@space.add_body  body
		@space.add_shape shape
		
		
		
		# store the Body / Shape objects, to iterate over them later
		@shapes ||= Array.new
		@shapes << shape
		
		@bodies ||= Array.new
		@bodies << body
	end
	
	# get a list of all points near the target (within the given radius)
	def query(target, radius)
		# --- implementation using point query
		# layers = CP::ALL_LAYERS
		# group  = CP::NO_GROUP
		# 
		# 
		# selection = []
		# @space.point_query(target, layers, group) do |shape|
		# 	selection << shape.object
		# end
		# selection.uniq!
		# 
		# p selection
		
		
		# --- implementation using shape query
		query_body   = CP::Body.new(1,1)
		query_shape  = CP::Shape::Circle.new(query_body, radius)
		
		query_body.p = target
		
		selection = []
		@space.shape_query(query_shape) do |colliding_shape|
			selection << colliding_shape.body
		end
		selection.uniq!
		
		p selection
		
		return selection
	end
	
	def to_a
		# p @bodies
		# p @bodies.collect{ |b| b.p }
		
			# The @bodies are unchanging, but the position vectors are constantly being reallocated. It seems like every time you ask for the position of a body, you get a new vector. This is good, because it means the vector you get straight off a body won't cause mutation by accident, but this can be rather inefficient. Be on the look out for performance problems.
		
		# NOTE: DO NOT use clone here. Want to pass the same exact data.
		# (currently passing the same information, but new objects every time)
		# (see big comment above for details)
		@bodies.collect{ |b| b.p }
	end
	
	private
	
	# Query the space, finding all shapes at the point specified.
	# Returns a list of the objects attached to the discovered shapes.
	# Each object will only appear once within the list.
	# Query does not make any guarantees about the order in which objects are returned.
	# TODO: adjust API so accepting block is not necessary (method chaining is more flexible)?
	def point_query(point, layers=CP::ALL_LAYERS, group=CP::NO_GROUP, limit_to:nil, exclude:nil, &block)
		# block params: |object_in_space|
		
		selection = []
		@space.point_query(point, layers, group) do |shape|
			selection << shape.obj
		end
		# NOTE: will pull basic Entity data, as well as Groups, because both live in the Space
		
		selection.uniq!
		
		# NOTE: potentially want to filer Groups by 'abstraction layer'
			# raw entities have abstraction layer = 0
			# a group with a raw entity inside it is layer = 1
			# in general: groups have layer = highest member layer value + 1
		# would need to somehow visualize abstraction layer,
		# as well as the current depth of selection
		# if that is going to be a thing.
		
		selection.select!{ |x| limit_to.include? x  }  if limit_to
		selection.reject!{ |x| exclude.include?  x  }  if exclude
		
		
		selection.each &block if block
		
		return selection
	end
end


class MouseHandler
	def initialize(button_id)
		@button_id = button_id
	end
	
	# define case equality: see if the desired button is pressed
	def ===(button_id)
		return @button_id == button_id
	end
	
	def click(vec)
		
	end
	
	def drag(vec)
		
	end
	
	def release(vec)
		
	end
end

class LeftClickHandler < MouseHandler
	def click(vec)
		
	end
	
	def drag(vec)
		
	end
	
	def release(vec)
		
	end
end

class RightClickHandler < MouseHandler
	def click(vec, point_data)
		@start_point = vec
		
		@point_bodies = point_data.query vec, 5
		@original_positions = @point_bodies.collect{ |b| b.p.clone }
	end
	
	# Don't just add deltas every frame.
	# That will accumulate error over time (floating point vectors).
	# Instead, calculate a delta from the original mouse click position,
	# and apply to each and every body in the selection every frame.
	def drag(vec)
		delta = vec - @start_point
		
		@point_bodies.zip(@original_positions).each do |body, original_pos|
			body.p = original_pos + delta
		end
	end
	
	def release(vec)
		drag(vec)
		
		@point_bodies = nil
		@original_positions = nil
	end
end
	
	
	include LiveCoding::InspectionMixin
	include RubyOF::Graphics
	
	
	def setup(window, save_directory)
		# basic initialization
		@window = window
		
		
		
		@click_handlers = {
			:left  =>  LeftClickHandler.new(0),
			:right => RightClickHandler.new(2)
		}
		
		
		
		
		@fonts = {
			:standard  => RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
				x.size = 20
				x.add_alphabet :Latin
				x.add_alphabet :Japanese
				
				# TODO: how do you discover what the alphabets are?
				# stored in RubyOF::TtfSettings::UnicodeRanges
				# maybe provide discoverable access through #alphabets on the DSL object?
			end,
			
			:monospace => RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
				x.size = 18
				x.add_alphabet :Latin
			end
		}
		
		
		
		@display   = TextEntity.new(@window, @fonts[:standard])
		@display.p = CP::Vec2.new 200, 273
		
		@p = [nil, nil]
		
		
		
		REPL.connect binding
		
		
		
		# @color = RubyOF::Color.new.tap do |c|
		# 	c.r, c.g, c.b, c.a = [0, 141, 240, 255]
		# end
		
		
		
		@point_data = PointData.new(z=0, r=4)
		
		
		# load data from disk
		filepath = save_directory/'mouse_data.yaml'
		if filepath.exist?
			File.open(filepath, 'r') do |f| 
				data = YAML.load(f)
				data.each do |type, *args|
					case type
						when 'point'
							vec = CP::Vec2.new(*args)
							@point_data.add vec
						else
							raise "ERROR: Unexpected type in serialization"
					end
				end
			end
		end
		
		
		
		
		@spatial_db = SpatialDB.new(save_directory)
		
		
		
		
		# # == aoeuaoeu ==
		# points = 
		# [
		# 	CP::Vec2.new( 837.0, 439.0),
		# 	CP::Vec2.new(1131.0, 322.0),
		# 	CP::Vec2.new(1019.0, 659.0),
		# 	CP::Vec2.new(1337.0, 476.0),
		# 	CP::Vec2.new(1286.0, 614.0),
		# 	CP::Vec2.new(1436.0, 628.0),
		# 	CP::Vec2.new(1316.0, 668.0),
		# 	CP::Vec2.new(1701.0, 755.0),
		# 	CP::Vec2.new(1031.0, 904.0),
		# 	CP::Vec2.new(1043.0, 904.0),
		# 	CP::Vec2.new( 708.0, 183.0),
		# 	CP::Vec2.new(1361.0, 844.0)
		# ]
		
		# # ==========
		
		query_results = @spatial_db.test_query
		
		@db_display   = TextEntity.new(@window, @fonts[:monospace])
		@db_display.p = CP::Vec2.new 780, 40
		
		
		
		
		keys = query_results.first.keys
		
		header    = keys.to_a.collect{ |column_name|
		            	column_name.to_s
		            }.join("    ")
		main_rows = query_results
		            .collect{ |hash|
		            	keys.collect{ |key| hash[key] }
		            }.collect{ |row|
		            	row.join("   ")
		            }.join("\n")
		
		# TODO: Consider just pulling out the values from each row, instead of mapping the keys array. Can probably safely assume that each row in the results set has the exactly same keys, just with different values.
		
		@db_display.string = 
			[
				header,
				main_rows
			].flatten(1).join("\n")
			
		
		
		
		# REPL.connect(binding)
		
		# p @click_log[-1].methods
		
		# puts "click radius for points: "
		# p @click_log[-2].dist @click_log[-1]
		
		
		
		# @live_wrapper = LiveCoding::DynamicObject.new(
		# 	@window,
		# 	save_directory:   (root/'bin'/'data'),
		# 	dynamic_code_file:(root/'lib'/'live_coding'/'code'/'test.rb'),
		# 	method_contract:  [:serialize, :cleanup, :update, :draw]
		# )
		
		# @live_wrapper.setup # loads anonymous class, and initializes it
		
		
	end
	
	# save the state of the object (dump state)
	# 
	# Should return a Plain-Old Ruby Object
	# (likely Array or Hash as the outer container)
	# (basically, something that could be trivially saved as YAML)
	def serialize(save_directory)
		@point_data.serialize(save_directory)
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
		@display.string = "mouse pos: #{@p.inspect}" # display mouse position
		@point_data.update
	end
	
	def draw
		# TODO: only need to re-generate Entities::Point objects from raw point data when point data is changed		
		@point_data.draw(@window, @fonts[:monospace])
		
		
		
		@display.draw
		@db_display.draw
	end
	
	
	
	
	# TODO: consider adding additional callbacks for input / output connections to other computational units (this is for when you have a full graph setup to throw data around in this newfangled system)
	
	# TODO: at that point, you need to be able to write code for those nodes in C++ as well, so the anonymous classes created in this file, etc, must be subclasses of some kind of C++ type (maybe even some sort of weak ref / smart pointer that allows for C++ memory allocation? (pooled memory?))
	
	
	
	# NOTE: Can't use the name 'send' because the #send method is what allows you to call arbitrary methods using Ruby's message passing interface.
	
	# send data to another live coding module in memory
	# (for planned visual coding graph)
	# NOTE: Try not to leak state (send immutable data, functional style)
	def send_data
		return @point_data.to_a
	end
	
	# recive data from another live-coding module in memory
	# (for planned visual coding graph)
	def recieve_data(input_data)
		
	end
	
	
	
	def mouse_moved(x,y)
		@p = [x,y]
	end
	
	def mouse_pressed(x,y, button)
		mouse_pos = CP::Vec2.new(x,y)
		
		case button
			when 0 # left
				@point_data.add mouse_pos
			when 1 # middle
				
			when 2 # right
				@click_handlers[:right].click(mouse_pos, @point_data)
			when 3 # prev (extra mouse button)
					
			when 4 # next (extra mouse button)
				
		end
		
	end
	
	def mouse_released(x,y, button)
		mouse_pos = CP::Vec2.new(x,y)
		
		case button
			when 0 # left
				
			when 1 # middle
				
			when 2 # right
				@click_handlers[:right].release(mouse_pos)
			when 3 # prev (extra mouse button)
					
			when 4 # next (extra mouse button)
				
		end
		
	end
	
	def mouse_dragged(x,y, button)
		mouse_pos = CP::Vec2.new(x,y)
		
		case button
			when 0 # left
				
			when 1 # middle
				
			when 2 # right
				@click_handlers[:right].drag(mouse_pos)
			when 3 # prev (extra mouse button)
					
			when 4 # next (extra mouse button)
				
		end
		
	end


	
end; return obj }

