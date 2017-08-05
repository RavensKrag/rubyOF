require 'pathname'

class Window < RubyOF::Window
	include RubyOF::Graphics
	
	def initialize
		super("Database Connection Test", 1746,1374)
		# ofSetEscapeQuitsApp false
		
		puts "ruby: Window#initialize"
		
		
		@p = [0,0]
		
		@project_root = Pathname.new(__FILE__).expand_path.dirname.parent
	end
	
	def setup
		super()
		
		# ***OBJECTIVES OF THIS PROJECT***
		
		# Need to set up 'sequel' gem
		# + with SQLite backend
		# + and SpatiaLite extension (GIS spatial query support)
		
		# ================================
		
		
		# sequel example code is from the main webpage for 'sequel' gem
		# => http://sequel.jeremyevans.net
		
		# gem dependencies are being loaded via Bundler
		# (see Gemfile in project root to see what gems are being loaded)
		
		@testing = false
		
		@db =
			if @testing
				# connect to test DB in memory
				@db = Sequel.sqlite
			else
				# connect to real DB on the disk
				path = @project_root/'bin'/'data'/'spatial_data.db'
				puts path
				@db = Sequel.connect("sqlite://#{path}")
			end
		
		# (from the docs: http://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html)
		# 
		# You can also pass an additional option hash with the connection string:
		# 
		# 	DB = Sequel.connect('postgres://localhost/blog', :user=>'user', :password=>'password')
		# [...]
		# [for sqlite specifically]
		# The following additional options are supported:
			# :readonly	
			# open database in read-only mode
			# 
			# :timeout	
			# the busy timeout to use in milliseconds (default: 5000).
		# 
		
		
		# NOTE: SQLite database file will not be created until you create a table
		@db.create_table :items do
			primary_key :id
			String :name
			Float :price
		end
		
		@db[:items].tap do |items|
			# populate the table
			items.insert(:name => 'abc', :price => rand * 100)
			items.insert(:name => 'def', :price => rand * 100)
			items.insert(:name => 'ghi', :price => rand * 100)

			# print out the number of records
			puts "Item count: #{items.count}"

			# print out the average price
			puts "The average price is: #{items.avg(:price)}"
		end
		
		
		
		
		# load spatialite
		@db.run "SELECT load_extension('mod_spatialite');"
	end
	
	def update
		# super()
		
		
	end
	
	def draw
		# super()
		
		
		# The size of the characters in the oF bitmap font is
		# height 11 px
		# width : 8 px
		
		start_position = [40, 30]
		row_spacing    = 11 + 4
		z              = 1
		draw_debug_info(start_position, row_spacing, z)
	end
	
	def on_exit
		super()
	end
	
	
	
	
	def key_pressed(key)
		super(key)
		
		begin
			string = 
				if key == 32
					"<space>"
				elsif key == 13
					"<enter>"
				else
					key.chr
				end
				
			puts string
		rescue RangeError => e
			
		end
	end
	
	def key_released(key)
		super(key)
	end
	
	
	
	
	
	def mouse_moved(x,y)
		@p = [x,y]
	end
	
	def mouse_pressed(x,y, button)
		super(x,y, button)
		
		ofExit() if button == 8
		# different window systems return different numbers
		# for the 'forward' mouse button:
			# GLFW: 4
			# Glut: 8
		# TODO: set button codes as constants?
		
	end
	
	def mouse_released(x,y, button)
		super(x,y, button)
	end
	
	def mouse_dragged(x,y, button)
		super(x,y, button)
	end
	
	
	
	private
	
	def draw_debug_info(start_position, row_spacing, z=1)
		[
			"mouse: #{@p.inspect}",
			"window size: #{window_size.to_s}",
			"dt: #{ofGetLastFrameTime.round(5)}",
			"fps: #{ofGetFrameRate.round(5)}",
			"time (uSec): #{RubyOF::Utils.ofGetElapsedTimeMicros}",
			"time (mSec): #{RubyOF::Utils.ofGetElapsedTimeMillis}"
		].each_with_index do |string, i|
			x,y = start_position
			y += i*row_spacing
			
			ofDrawBitmapString(string, x,y,z)
		end
	end
end
