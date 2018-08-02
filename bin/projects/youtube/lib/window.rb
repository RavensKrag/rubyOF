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
current_file.parent.tap do |lib_dir|
	require lib_dir/'helpers.rb'
	require lib_dir/'fibers.rb'
	require lib_dir/'camera.rb'
	
	require lib_dir/'youtube_channel.rb'
	
	require lib_dir/'space.rb'
	
	require_all lib_dir/'history'
	require_all lib_dir/'monkey_patches'/'Chipmunk'
	
	require_all lib_dir/'entities'
	
	
	# require lib_dir/'live_coding'/'code_loader'
	
	require_all lib_dir/'live'/'loader'
	require lib_dir/'live'/'coroutines'/'turn_counter'
	require_all lib_dir/'live'/'history'
end



class Window < RubyOF::Window
	include HelperFunctions
	
	attr_reader :live
	
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
		
		
	end
	
	attr_reader :history
	# needed to interface with the C++ history UI code
	
	def setup
		super()
		
		@data_dir = PROJECT_DIR / 'bin' / 'data'
		# NOTE: All files should be located in @data_dir (Pathname object)
		
		@font = 
			RubyOF::TrueTypeFont.new.dsl_load do |x|
				# TakaoPGothic
				x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
				x.size = 50
				x.add_alphabet :Latin
			end
		# @font_color = RubyOF::Color.new.tap do |c|
		# 	c.r, c.g, c.b, c.a = [171, 160, 228, 255]
		# end
		# ^ font color is currently being set through the color picker
		
		
		
		
		@space = Space.new
		
		@history = History.new @space
		
		
		@live =
			LiveCoding::Loader.new(
				"Body",
				header: (PROJECT_DIR/'lib'/'live'/'code'/'body_init.rb'),
				body:   (PROJECT_DIR/'lib'/'live'/'code'/'body_main.rb'),
				save_directory: @data_dir,
				
				method_contract:  [
					:update, :draw,
					:mouse_moved, :mouse_pressed, :mouse_dragged, :mouse_released,
					:mouse_scrolled
				]
			)
		
		# @live_coding = LiveCoding::DynamicObject.new(
		# 	self,
		# 	save_directory:   (PROJECT_DIR/'bin'/'data'),
		# 	dynamic_code_file:(PROJECT_DIR/'lib'/'live_coding'/'code'/'main.rb'),
			
		# 	parameters:[@space, @font],
			
		# 	method_contract:  [
		# 		:serialize, :cleanup, :update, :draw,
		# 		:mouse_moved, :mouse_pressed, :mouse_released, :mouse_dragged
		# 	]
		# )
		
		# @live_coding.setup
	end
	
	def update
		# super()
		clear_text_buffer
		@live.font_color = @font_color
		@live.update(self)
	end
	
	def draw
		# super()
		
		@live.draw(self)
		
		
		unless @text_buffer.nil?
			@text_buffer.texture.bind
			@text_buffer.draw 
			@text_buffer.texture.unbind
		end
	end
	
	def on_exit
		super()
		
		# @live_coding.on_exit
		
		# --- Save data
		dump_yaml [self.width, self.height] => @window_dimension_save_file
		
		# # --- Clear variables that might be holding onto OpenFrameworks pointers.
		# # NOTE: Cases where Chipmunk can hold onto OpenFrameworks data are dangerous. Must free Chimpunk data using functions like cpSpaceFree() during the lifetime of OpenFrameworks data (automatically called by Chipmunk c extension on GC), otherwise a segfault will occur. However, this segfault will occur inside Chipmunk code, which is very confusing.
		# @space = nil
		# @history = nil
		
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
		@live.mouse_moved(x,y)
	end
	
	def mouse_pressed(x,y, button)
		super(x,y, button)
		
		ofExit() if button == 8
		# different window systems return different numbers
		# for the 'forward' mouse button:
			# GLFW: 4
			# Glut: 8
		# TODO: set button codes as constants?
		
		# case button
		# 	when 1 # middle click
		# 		@drag_origin = CP::Vec2.new(x,y)
		# 		@camera_origin = @camera.pos.clone
		# end
		
		@live.mouse_pressed(x,y, button)
	end
	
	def mouse_dragged(x,y, button)
		super(x,y, button)
		
		# case button
		# 	when 1 # middle click
		# 		pt = CP::Vec2.new(x,y)
		# 		d = (pt - @drag_origin)/@camera.zoom
		# 		@camera.pos = d + @camera_origin
		# end
		
		@live.mouse_dragged(x,y, button)
	end
	
	def mouse_released(x,y, button)
		super(x,y, button)
		
		# case button
		# 	when 1 # middle click
				
		# end
		
		@live.mouse_released(x,y, button)
	end
	
	def mouse_scrolled(x,y, scrollX, scrollY)
		super(x,y, scrollX, scrollY) # debug print
		
		# zoom_factor = 1.05
		# if scrollY > 0
		# 	@camera.zoom *= zoom_factor
		# elsif scrollY < 0
		# 	@camera.zoom /= zoom_factor
		# else
			
		# end
		
		# puts "camera zoom: #{@camera.zoom}"
		
		@live.mouse_scrolled(x,y, scrollX, scrollY)
	end
	
	
	
	# this is for drag-and-drop, not for mouse dragging
	def drag_event(files, position)
		p [files, position]
		
		# 	./lib/main.rb:41:in `show': Unable to convert glm::tvec2<float, (glm::precision)0>* (ArgumentError)
		# from ./lib/main.rb:41:in `<main>'
		
		# the 'position' variable is of an unknown type, leading to a crash
	end
	
	def show_text(pos, obj)
		@text_buffer = Text.new(@font, obj.to_s)
		@text_buffer.text_color = @font_color
		
		@text_buffer.update
		
		@text_buffer.body.p = pos
	end
	
	def clear_text_buffer
		@text_buffer = nil
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
		
		# TODO: delegate core of this method to Loader, and then to the wrapped object inside. Want to be able to controll this dynamically.
		
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
