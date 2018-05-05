require 'fiber'

require 'nokogiri'
require 'json'
require 'yaml'

require 'uri' # needed to safely / easily join URLs

require 'pathname'
require 'fileutils'

require 'chipmunk'

require 'require_all'


current_file = Pathname.new(__FILE__).expand_path
current_dir  = current_file.parent

Dir.chdir current_dir do
	require Pathname.new('./helpers.rb').expand_path
	require Pathname.new('./fibers.rb').expand_path
	require Pathname.new('./camera.rb').expand_path
	
	require Pathname.new('./youtube_channel.rb').expand_path
	
	require Pathname.new('./space.rb').expand_path
	
	require_all Pathname.new('./history').expand_path
	require_all Pathname.new('./monkey_patches/Chipmunk').expand_path
	
	require_all Pathname.new('./entities').expand_path
end



class Window < RubyOF::Window
	include HelperFunctions
	include RubyOF::Graphics
	
	PROJECT_DIR = Pathname.new(__FILE__).expand_path.parent.parent
	def initialize
		@window_dimension_save_file = PROJECT_DIR/'bin'/'data'/'window_size.yaml'
		
		window_size = YAML.load_file(@window_dimension_save_file)
		w,h = *window_size
		
		# super("Youtube Subscription Browser", 1853, 1250)
		super("Youtube Subscription Browser", w,h) # half screen
		# super("Youtube Subscription Browser", 2230, 1986) # overlapping w/ editor
		
		# ofSetEscapeQuitsApp false
		
		puts "ruby: Window#initialize"
		
		
		@p = [0,0]
		
		
		
	end
	
	attr_reader :history
	
	def setup
		super()
		
		@camera = Camera.new(self.width/2, self.height/2)
		
		
		current_file = Pathname.new(__FILE__).expand_path
		current_dir  = current_file.parent
		project_dir  = current_dir.parent
		@data_dir = project_dir / 'bin' / 'data'
		# NOTE: All files should be located in @data_dir (Pathname object)
		
		@font = 
			RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
				x.size = 20
				x.add_alphabet :Latin
				x.add_alphabet :Japanese
			end
		# @font_color = RubyOF::Color.new.tap do |c|
		# 	c.r, c.g, c.b, c.a = [171, 160, 228, 255]
		# end
		# ^ font color is currently being set through the color picker
		
		@collection = Array.new
		
		
		
		
		@space = Space.new
		
		@history = History.new @space
		
		
		text = Text.new(@font, "hello world! This is a pen.")
		@space.add text
	end
	
	def update
		# super()
		
		
		# NOTE: The fiber must be created in #update to be used in #update
		#       If it is created in one callback and then called from another:
		#       => FiberError: fiber called across stack rewinding barrier
		
		# As a side effect of using a fiber, you can kill
		# the downloding process in the middle by just
		# closing the Window
		
		@update_fiber ||= Fiber.new do	
			local_channel_info = cache @data_dir/'channel_info.yml' do 
				# ==========
				# ====================
				html_file = path("./youtube_subscriptions.html")
				channel_info_list = parse_youtube_subscriptions(html_file)
				
				enum = 
					channel_info_list
					.lazy
					.collect{ |data|
						# channel info -> icon paths on disk
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
						
						# returns path to file when download is complete
						download(icon_url => output_path)
					}
					.zip(channel_info_list)
					.collect{ |icon_filepath, channel_info|
						# reformat data so channel icons are referenced
						# by file paths, not by URLs.
						
						# puts "reformating data..."
						{
							'channel-name'  => channel_info['channel-name'],
							'link'          => channel_info['link'],
							'icon-filepath' => icon_filepath,
							'entry-count'   => channel_info['entry-count']
						}
					}
					.each
				# ====================
				# ==========
				
				# download all icons, pausing after each icon
				Array.new.tap do |out|
					enum.each do |x|
						out << x
						Fiber.yield
					end
				end
			end
			
			
			
			# load data into memory
			# ---
			enum = 
				local_channel_info
				.lazy
				.collect{ |data|
					# load icons
					RubyOF::Image.new.dsl_load do |x|
						x.path = data['icon-filepath'].to_s
						# x.enable_accurate
						# x.enable_exifRotate
						# x.enable_grayscale
						# x.enable_separateCMYK
					end
				}
				.zip(local_channel_info).each_with_index.collect{ |zip_pair, i|
					# yt channel data + icon -> object in memory
					image, data = zip_pair
					# -----
					pos = CP::Vec2.new(100,150)
					dx = 400 # space between columns
					dy = 100 # space between rows
					offset = CP::Vec2.new(100, 50) # offset between icon and text
					
					slices = 18
					
					YoutubeChannel.new(image, data['channel-name'], @font).tap do |yt|
						ix = i / slices
						iy = i % slices
						
						# Icon
						yt.icon_pos.x = pos.x + dx*ix
						yt.icon_pos.y = pos.y + dy*iy
						
						# Text
						yt.text_pos.x = pos.x + dx*ix + offset.x
						yt.text_pos.y = pos.y + dy*iy + offset.y
						yt.text_color = @font_color
						
						
						
						
						# create icon as an Image entity
						icon = Image.new(image)
						icon.body.p.x = pos.x + dx*ix
						icon.body.p.y = pos.y + dy*iy
						
						@space.add icon
						
						
						# create text as free-floating Text entity
						# (this is what actually gets rendered)
						text = Text.new(@font, data['channel-name'])
						text.body.p.x = pos.x + dx*ix + offset.x
						text.body.p.y = pos.y + dy*iy + offset.y
						text.text_color = @font_color
						
						text.update
						
						@space.add text
					end
				}.each
			# load one piece of yt channel data at a time, pausing after each piece
			enum.each do |x|
				@collection << x
				Fiber.yield
			end
			
			
			
			# Critical Question:
			# Do you want to save to disk after each piece of data is processed?
			# Or do you not want to save until you process the entire stream?
			# (remember that it is possible the stream has infinite length)
			
			
			# Do a sort of busy loop at the end for now,
			# just to keep the main Fiber alive.
			loop do
				Fiber.yield
			end
		end
		
		
		@space.update
		@update_fiber.resume
		
		
		
		
		# FIXME: Consider changing how helper functions are declared / used
		
		
		# TODO: use Fiber to create download progress bar / spinner to show progress in UI (not just in the terminal)
		
		
		
		
		
		
		# -- implement basic "live coding" environment
		#    (update doesn't necessarily need to be instant)
		#    (but should be reasonably fast)
		
		# TODO: split Fiber definiton into separate reloadable files, or similar, so that these independent tasks can be redefined without having to reload the entire application.
		
		
		
		
		
		# -- allow direct manipulation of the data
		#    (control layout of elements with mouse and keyboard, not code)
		
		
		
		
		# -- add more YouTube subscriptions without losing existng organization
		
		
		
		
		# -- click on links and go to YouTube pages
		
		
		
		# require 'irb'
		# binding.irb
		
		# =====                   =====
		
		# NOTE: To pass data between #update and #draw, use an instance variable
		#       (can't resume a Fiber declared in one callback from the other)
		
		
	end
	
	def draw
		# super()
		
		
		@draw_debug_ui ||= Fiber.new do
			c = RubyOF::Color.new
			# c.r, c.g, c.b, c.a = [171, 160, 228, 255]
			c.r, c.g, c.b, c.a = [0, 0, 0, 255]
			
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
		
		# # accept input on every #resume
		# @draw_color_picker ||= Fiber.new do 
		# 	# -- render data
		# 	loop do
				
				
		# 		Fiber.yield # <----------------
		# 	end
		# end
		
		
		
		# === Draw world relative
		@camera.draw self.width, self.height do |bb|
			render_queue = Array.new
			
			@space.bb_query(bb) do |entity|
				render_queue << entity
			end
			
			# puts "render queue: #{render_queue.size}"
			# ^ if this line is active, get segfault on standard exit
			
			
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
		@draw_debug_ui.resume
		# @draw_color_picker.resume
		# =======
	end
	
	def on_exit
		super()
		
		
		# --- Save data
		dump_yaml [self.width, self.height] => @window_dimension_save_file
		
		# --- Clear variables that might be holding onto OpenFrameworks pointers.
		# NOTE: Cases where Chipmunk can hold onto OpenFrameworks data are dangerous. Must free Chimpunk data using functions like cpSpaceFree() during the lifetime of OpenFrameworks data (automatically called by Chipmunk c extension on GC), otherwise a segfault will occur. However, this segfault will occur inside Chipmunk code, which is very confusing.
		@space = nil
		@history = nil
		
		# --- Clear Ruby-level memory
		GC.start
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
		
		case button
			when 1 # middle click
				@drag_origin = CP::Vec2.new(x,y)
				@camera_origin = @camera.pos.clone
		end
	end
	
	def mouse_dragged(x,y, button)
		super(x,y, button)
		
		case button
			when 1 # middle click
				pt = CP::Vec2.new(x,y)
				d = (pt - @drag_origin)/@camera.zoom
				@camera.pos = d + @camera_origin
		end
	end
	
	def mouse_released(x,y, button)
		super(x,y, button)
		
		case button
			when 1 # middle click
				
		end
	end
	
	def mouse_scrolled(x,y, scrollX, scrollY)
		super(x,y, scrollX, scrollY) # debug print
		
		zoom_factor = 1.05
		if scrollY > 0
			@camera.zoom *= zoom_factor
		elsif scrollY < 0
			@camera.zoom /= zoom_factor
		else
			
		end
		
		puts "camera zoom: #{@camera.zoom}"
	end
	
	
	
	# this is for drag-and-drop, not for mouse dragging
	def drag_event(files, position)
		p [files, position]
		
		# 	./lib/main.rb:41:in `show': Unable to convert glm::tvec2<float, (glm::precision)0>* (ArgumentError)
		# from ./lib/main.rb:41:in `<main>'
		
		# the 'position' variable is of an unknown type, leading to a crash
	end
	
	
	
	# NOTE: regaurdless of if you copy the values over, or copy the color object, the copying slows things down considerably if it is done repetedly. Need to either pass one pointer from c++ side to Ruby side, or need to wrap ofParameter and use ofParameter#makeReferenceTo to ensure that the same data is being used in both places.
	# OR
	# you could use ofParameter#addListener to fire an event only when the value is changed (that could work)
		# May still want to bind ofParameter on the Ruby side, especially if I can find a way to allow for setting event listeners in Ruby.
	# def font_color=(color)
	# 	p color
	# 	# puts color
	# 	# 'r g b a'.split.each do |channel|
	# 	# 	@font_color.send("#{channel}=", color.send(channel))
	# 	# end
	# 	@font_color = color
	# 	@font_color.freeze
	# end
	
	
	# Set parameters from C++ by passing a pointer (technically, a reference),
	# wrapped up in a way that Ruby can understand.
	# 
	# name         name of the parameter being set
	# value_ptr    &data from C++, wrapped up in a Ruby class
	#              (uses the same class wrapper as normal Rice bindings)
	def set_gui_parameter(name, value_ptr)
		value_ptr.freeze
		
		case name
			when "color"
				@font_color = value_ptr
			else
				msg = 
				[
					"",
					"Tried to set gui parameter, but I wasn't expecting this name.",
					"method call: set_gui_parameter(name, value_ptr)",
					"name:        #{name.inspect}",
					"value_ptr:   #{value_ptr.inspect}",
					"",
					"NOTE: set_gui_parameter() is often called from C++ code.",
					"      C++ backtrace information is not normally provided.",
					"",
					"NOTE: Sometimes C++ backtrace can be obtained using GDB",
					"      (use 'rake debug' to get a GDB prompt)"
				].join("\n") + "\n\n\n"
				
				raise msg
		end
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
	
	
	# input_path          path to the input HTML file
	# test_output_path    path that Nokogiri can write to, to ensure parsing works
	def parse_youtube_subscriptions(html_filepath, test_output_path=nil)
		# + open youtube in firefox
		# + open sidebar
		# + scroll down to the bottom of all the subscriptions (to load all of them)
		# + use "inspect" tool
		# + visually select the "SUBSCRIPTIONS" header
		# + find the HTML element that contains all subscription links / buttons
		# + in inspector: right click -> Copy -> Outer HTML
		# => saved that data to file, and load it up here in Nokogiri
		doc = open_html_file(html_filepath)

		# If a debug output location has been specified,
		# rewrite this data back out to file, to see how
		# Nokogiri cleans the data
		unless test_output_path.nil?
			File.open(test_output_path, 'w') do |f|
				f.print doc.to_xhtml(indent:3, indent_text:' ')
			end
		end
		
		# Basic document structure
		# ---
		# 'ytd-guide-section-renderer'
		 # 'ytd-guide-entry-renderer'
		   # 'a'
		     # ["text", "yt-icon", "yt-img-shadow", "span", "text", "span", "text"] 
		
		
		subscription_links = doc.css('ytd-guide-section-renderer > div#items a')
		
		# -- parse all subscriptions
		
		# sub_data[0].attributes['disable-upgrade'] # JSON payload, gives URL to icon
		# # => #<Nokogiri::XML::Attr:0x1257c58 name="disable-upgrade" value="{\"thumbnails\":[{\"url\":\"https://yt3.ggpht.com/-DqhnQ70YsRo/AAAAAAAAAAI/AAAAAAAAAAA/TTVyaxv3Xag/s88-c-k-no-mo-rj-c0xffffff/photo.jpg\"}],\"webThumbnailDetailsExtensionData\":{\"isPreloaded\":true,\"excludeFromVpl\":true}}"> 
		# sub_data[1] # HTML element with the actual icon
		# sub_data[2] # SPAN -> channel name
		# sub_data[3] # SPAN -> 'entry-count'

		subscription_links.collect do |anchor_tag|
			link = anchor_tag.attributes['href'].value

			# ----

			sub_data = anchor_tag.children.reject{ |x| x.name == 'text' }


			# JSON payload, gives URL to icon
			json_text = sub_data[0].attributes['disable-upgrade']
			# => #<Nokogiri::XML::Attr:0x1257c58 name="disable-upgrade" value="{\"thumbnails\":[{\"url\":\"https://yt3.ggpht.com/-DqhnQ70YsRo/AAAAAAAAAAI/AAAAAAAAAAA/TTVyaxv3Xag/s88-c-k-no-mo-rj-c0xffffff/photo.jpg\"}],\"webThumbnailDetailsExtensionData\":{\"isPreloaded\":true,\"excludeFromVpl\":true}}"> 

			json_data = JSON.parse(json_text)
			json_icon_url = json_data['thumbnails'][0]['url']


			img = sub_data[1].css('img')[0]             # yt-img-shadow > img -> icon
			html_icon_url = img.attributes['src'].value 

			channel_name  = sub_data[2].text             # SPAN -> channel name
			entry_count   = sub_data[3].text.strip.to_i  # SPAN -> 'entry-count' 


			# RETURN
			data = {
				'link'          => URI.join("https://www.youtube.com/", link).to_s,
				# without casting, the type after URI.join() => URI::HTTPS

				'json-icon-url' => json_icon_url,
				'html-icon-url' => html_icon_url,
				'channel-name'  => channel_name,
				'entry-count'   => entry_count,
			}
		end
	end
end
