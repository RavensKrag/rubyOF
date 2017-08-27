# (create instance of Object class, and define things on it's singleton class)
->(){ obj = Object.new; class << obj



class Entity
	def initialize
		
	end
end

class Point < Entity
	attr_reader :p
	attr_accessor :z
	
	class << self
		def r
			4
		end
	end
	
	def initialize(window)
		@window = window
		
		@color =
			RubyOF::Color.new.tap do |c|
				c.r, c.g, c.b, c.a = [0, 141, 240, 255]
			end
		@p = CP::Vec2.new(0,0)
		@z = 0
	end
	
	def draw
		@window.tap do |w|
			w.ofPushStyle()
			w.ofSetColor(@color)
			
			w.ofDrawCircle(@p.x, @p.y, @z, self.class.r)
			
			w.ofPopStyle()
		end
	end
end

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
	
	
	include LiveCoding::InspectionMixin
	include RubyOF::Graphics
	
	
	def setup(window, save_directory)
		# basic initialization
		@window = window
		
		
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
		
		
		@space = CP::Space.new
		
		
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
		@display.string = "mouse pos: #{@p.inspect}" # display mouse position
	end
	
	def draw
		@click_log.each_with_index do |point, i|
			ofPushStyle()
			ofSetColor(@color)
			
			
			# -- render the actual point data
			x,y = point.to_a
			z = 0
			r = 5
			ofDrawCircle(x,y,z, r)
			
			
			# -- render the index of each point, above where the point is
			
			char_to_px = 18 # string width to horiz displacement 
			
			label = i.to_s
			@fonts[:monospace].tap do |font|
				width  = font.string_width(label)
				
				# NOTE: strings appear to draw from the bottom left corner
				font.draw_string(
					i.to_s,
					
					x - (width) / 2,
					y - r*2 # neg y is up the screen
				)
			end
			
			
			
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
		
		@display.draw
		@db_display.draw
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
		@p = [x,y]
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

