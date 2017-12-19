require 'fiber'

require 'nokogiri'
require 'json'
require 'yaml'

require 'uri' # needed to safely / easily join URLs

require 'pathname'
require 'fileutils'

require 'chipmunk'


current_file = Pathname.new(__FILE__).expand_path
current_dir  = current_file.parent

Dir.chdir current_dir do
	require Pathname.new('./helpers.rb').expand_path
  require Pathname.new('./fibers.rb').expand_path
end


class Window < RubyOF::Window
	include RubyOF::Graphics
	
	def initialize
		# super("Youtube Subscription Browser", 1853, 1250)
		super("Youtube Subscription Browser", 1853, 1986)
		
		# ofSetEscapeQuitsApp false
		
		puts "ruby: Window#initialize"
		
		
		@p = [0,0]
		
		
		
	end
	
	def setup
		super()
		
		
		@font = 
			RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
				x.size = 20
				x.add_alphabet :Latin
				x.add_alphabet :Japanese
			end
	end
	
	def update
		# super()
		
		
		# NOTE: The fiber must be created in #update to be used in #update
		#       If it is created in one callback and then called from another:
		#       => FiberError: fiber called across stack rewinding barrier
		
		# As a side effect of using a fiber, you can kill
		# the downloding process in the middle by just
		# closing the Window
		
		# NOTE: Current render speed is ~12 fps while Fiber is active
		#       Not sure if this is a result of Fiber overhead, or download()
		
		@task1 ||= Task1.new
		data_path = @task1.resume
		
		
		# save the data path to a variable that can be shared between #update and #draw when the fiber sets this data path
		unless data_path.nil?
			@data_path = data_path
			
			puts "printing data path: "
			p @data_path
		end
		
		# TODO: use Fiber to create download progress bar / spinner to show progress in UI (not just in the terminal)
		
		
		
		# -- use OpenFrameworks to 'visualize' this data
		
		unless @data_path.nil?
			if @local_subscriptions.nil?
				@local_subscriptions = YAML.load_file(@data_path)
				puts "update: data loaded!"
			end
		end
		# NOTE: If you use Pathname with YAML loading, the type will protect you.
		# YAML.load() is for strings
		# YAML.load_file() is for files, but the argument can still be a string
		# but, Pathname is a vaild type *only* for load_file()
			# thus, even if you forget what the name of the method is, at least you don't get something weird and unexpected?
			# (would be even better to have a YAML method that did the expected thing based on the type of the argument, imo)
			# 
			# Also, this still doesn't help you remember the correct name...
		
		
		
		
		# first yield is just a signal that the file was loaded
		# subsequent yields update the 'images' array
		@p4_image_load ||= FiberQueue.new do
			# -- wait for needed variable to be set
			while @local_subscriptions.nil?
				Fiber.yield
			end
			
			# -- load channel icon
			images = Array.new
			
			@local_subscriptions.each do |data|
				new_image = 
					RubyOF::Image.new.dsl_load do |x|
						x.path = data['icon-filepath'].to_s
						# x.enable_accurate
						# x.enable_exifRotate
						# x.enable_grayscale
						# x.enable_separateCMYK
					end
				images << new_image
				
				
				Fiber.yield images # <----------------
			end
		end
		
		
		# load a number of images per frame
		20.times do
			out = @p4_image_load.resume
			if out.nil?
				# NO-OP
			elsif out.is_a? Array
				@images = out
			end
		end
		
		
		# -- implement basic "live coding" environment
		#    (update doesn't necessarily need to be instant)
		#    (but should be reasonably fast)
		
		# TODO: split Fiber definiton into separate reloadable files, or similar, so that these independent tasks can be redefined without having to reload the entire application.
		
		
		
		
		
		# -- implement basic camera control (zoom, pan)
		
		
		
		
		# -- allow direct manipulation of the data
		#    (control layout of elements with mouse and keyboard, not code)
		
		
		
		# -- implement color picker
		#    (maybe use oF c++ color picker that already exists?)
		
		
		
		# -- add more YouTube subscriptions without losing existng organization
		
		
		
		
		# -- click on links and go to YouTube pages
		
		
		
		# require 'irb'
		# binding.irb
		
		
	end
	
	def draw
		# super()
		
		ofPushMatrix()
		ofPushStyle()
		
			c = RubyOF::Color.new
			c.r, c.g, c.b, c.a = [171, 160, 228, 255]
			ofSetColor(c)
			
			
			
			# The size of the characters in the oF bitmap font is
			# height 11 px
			# width : 8 px
			
			start_position = [40, 30]
			row_spacing    = 11 + 4
			z              = 1
			draw_debug_info(start_position, row_spacing, z)
		
		ofPopStyle()
		ofPopMatrix()
		
		
		
		@p5_image_render ||= Fiber.new do
			# -- wait for data to be available
			while @images.nil?
				Fiber.yield
			end
			
			# -- render data
			loop do
				@images.zip(@local_subscriptions).each_with_index do |zip_pair, i|
					image, data = zip_pair
					# -----
					
					p = CP::Vec2.new(100,150)
					dx = 400 # space between columns
					dy = 100 # space between rows
					offset = CP::Vec2.new(100, 50) # offset between icon and text
					
					slices = 18
					ix = i / slices
					iy = i % slices
					
					# -- render icon
					x = p.x + dx*ix
					y = p.y + dy*iy
					z = 10 # arbitrary value
					image.draw(x,y, z)
					
					
					# -- render channel name
					x = p.x + dx*ix + offset.x
					y = p.y + dy*iy + offset.y
					# @font.draw_string("From ruby: こんにちは", x, y)
					@font.draw_string(data['channel-name'], x, y)
					
					# NOTE: to move string on z axis just use the normal ofTransform()
					# src: https://forum.openframeworks.cc/t/is-there-any-means-to-draw-multibyte-string-in-3d/13838/4
				end
				
				
				Fiber.yield # <----------------
			end
		end
		
		
		@p5_image_render.resume
		
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

