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
	require Pathname.new('./checkpoint.rb').expand_path
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
		
		
		current_file = Pathname.new(__FILE__).expand_path
		@current_dir  = current_file.parent
		
		Dir.chdir @current_dir do
			@font = 
				RubyOF::TrueTypeFont.new.dsl_load do |x|
					# TakaoPGothic
					x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
					x.size = 20
					x.add_alphabet :Latin
					x.add_alphabet :Japanese
				end
		
		
			@c1 = 
				Checkpoint.new.tap do |g|
					g.save_filepath = path('./local_data.yml')
					g.inputs  = { in_path:  path("./youtube_subscriptions.html") }
					g.outputs = { out_path: path('./nokogiri_cleaned_data.html'), 
					               c1_path: path('./data.yml') }
				end
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
		
		
		
		@main_update_fiber ||= Fiber.new do
		# === MAIN ===
		Dir.chdir @current_dir do
			# note on variable names
			# ---
			# p1  pathway     Performs a sequence of operations / transformations
			# c1  checkpoint  A good place to pause. Saves data on disk for later.
			
			@local_subscriptions = @c1.gate do |inputs, outputs|
				# -- parse HTML file and get youtube subscriptions
				# subscriptions = p1(inputs[:in_path], outputs[:out_path]) # create debug file to test loading
				subscriptions = p1(inputs[:in_path]) # no debug file
				
				# save intermediary data to file
				dump_yaml(subscriptions => outputs[:c1_path])
				Fiber.yield # <----------------
				
				
				# -- use subscription data to find icons for Youtube channels,
				#    and download all of the icons into a folder on the disk,
				@p2.resume(subscriptions)
				p2_out = nil
				while p2_out.nil?
					# @p2 yields nil after every download (like a 'sleep')
					p2_out = @p2.resume
					Fiber.yield # <----------------
				end
					# The final yield gives back the filepaths we need
				icon_filepaths = p2_out
				
				
				
				# -- Associate paths to icons on disk with Youtube channels
				#    reformat: [channel_name, link, icon_filepath]
				#    (going forward, icons will be accessed via filepaths, not URLs)
				local_subscriptions = p3(subscriptions, icon_filepaths)
				
				Fiber.yield # <----------------
				
				local_subscriptions # RETURN
			end
			
			# TODO: separate raw data files from intermediates
			#   Makes it a lot easier to clean up later
			#   if the intermediates are restricted to one directory
			
			
			
			# ---------------                          ---------------
			# At this point, youtube URLs and icon links are absolute,
			# rather than being relative to the youtube domain. This 
			# means we are free from thinking about YouTube in any way.
			# ---------------                          ---------------
			puts "TOTAL SUBSCIPTIONS: #{@local_subscriptions.size}"
			
			# -- use OpenFrameworks to 'visualize' this data
			# load a number of images per frame
			@p4_image_load.resume(@local_subscriptions)
			Fiber.yield # <----------------
			
			loop do
				4.times do
					# but if you have more loading to do, resume the Fiber
					out = @p4_image_load.resume
					# Fiber.yield # <----------------
					if out.nil?
						# NO-OP
					elsif out.is_a? Array
						@images = out
					end
				end
				
				Fiber.yield # <----------------
				break if @p4_image_load.state == :finished
			end
			# FIXME: Set @images once, and then append a new chunk of images to that array as necessary. As Array is a reference type, this will allow you to continuiously send data to the #draw Fiber, even though you only pass the reference once. I think?
			
			# FIXME: alias / delegate to Fiber.alive? instead of using this @p4_image_load.state call. I though it was weird that I had to manage that state manually... May actually want to consider getting rid of 	FiberQueue entirely now that the way I'm using Fibers is totally different.
			
			# FIXME: Change how p1() and similar functions are declared
			# FIXME: Consider changing how helper functions are declared / used
			
			
			# TODO: use Fiber to create download progress bar / spinner to show progress in UI (not just in the terminal)
			
			
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
			
			
			
			
			
			# Do a sort of busy loop at the end for now,
			# just to keep the main Fiber alive.
			loop do
				Fiber.yield
			end
		end # close Dir.chdir
		end # close Fiber
		
		
		
		# ===== Helper fibers =====
		
		# first yield is just a signal that the file was loaded
		# subsequent yields update the 'images' array
		@p2 ||= Fiber.new do |subscriptions|			
			# -- load channel icon
			# data = subscriptions.first
			
			icon_filepaths = 
			  subscriptions.collect do |data|
			    channel_url = data['link']
			    icon_url    = data['json-icon-url']
			    name        = data['channel-name']
			    
			    # -- download the icons for all YT channels in subscription list
			    puts "downloading icon for #{name}  ..."
			    
			    icon_dir  = Pathname.new("./icons/").expand_path
			    FileUtils.mkdir_p icon_dir
			    
			    
			    # Channel names may include characters that are illegal in paths,
			    # but the channel URLs should be OK for filesystem paths too
			    basename = (File.basename(channel_url) + File.extname(icon_url))
			    output_path = icon_dir + basename
			    download(icon_url => output_path)
			    
			    Fiber.yield # <----------------
			    
			    # RETURN
			    output_path
			  end
			# What do I need to save? The output directory name? The paths to all files?
			# They're all going to be under the same directory.
			# How will the system remember that the file names are channel identifiers?
			# Is that a job for the system, or for the programmer?
			
			Fiber.yield icon_filepaths # <----------------
		end
		
		# first yield is just a signal that the file was loaded
		# subsequent yields update the 'images' array
		@p4_image_load ||= FiberQueue.new do |local_subscriptions|
			# After accepting initial argument, just sleep for one frame
			# just to make things easier to schedule
			Fiber.yield # <---------------- 
			
			
			# -- load channel icon
			images = Array.new
			
			local_subscriptions.each do |data|
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
		
		# =====                   =====
		
		
		
		
		@main_update_fiber.resume
		
		# NOTE: To pass data between #update and #draw, use an instance variable
		#       (can't resume a Fiber declared in one callback from the other)
		
		
	end
	
	def draw
		# super()
		
		
		
		
		@main_draw_fiber ||= Fiber.new do
			# wait for the data twe need to be generated by the #update Fiber
			while @images.nil? or @local_subscriptions.nil?
				Fiber.yield
			end
			
			
			# Start the actual work now
			
			
			# Render a bunch of different tasks
			loop do
				# TODO: only render the task if it is still alive (allow for non-looping tasks)
				@p6_debug_ui_render.resume
				@p5_image_render.resume(@images, @local_subscriptions)
				Fiber.yield # <----------------
			end
		end
		
		
		@p6_debug_ui_render ||= Fiber.new do
			c = RubyOF::Color.new
			c.r, c.g, c.b, c.a = [171, 160, 228, 255]
			
			loop do
				ofPushMatrix()
				ofPushStyle()
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
				
				Fiber.yield # <----------------
			end
		end
		
		# accept input on every #resume
		@p5_image_render ||= Fiber.new do |images, local_subscriptions|
			# -- render data
			loop do
				images.zip(local_subscriptions).each_with_index do |zip_pair, i|
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
				
				
				images, local_subscriptions = Fiber.yield # <----------------
			end
		end
		
		
		@main_draw_fiber.resume
		
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
