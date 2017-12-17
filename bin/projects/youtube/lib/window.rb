require 'nokogiri'
require 'json'
require 'yaml'

require 'uri' # needed to safely / easily join URLs

require 'pathname'
require 'fileutils'


class Window < RubyOF::Window
	include RubyOF::Graphics
	
	def initialize
		super("Youtube Subscription Browser", 1853, 1250)
		# ofSetEscapeQuitsApp false
		
		puts "ruby: Window#initialize"
		
		
		@p = [0,0]
		
		
		
	end
	
	def setup
		super()
		
	end
	
	def update
		super()
		
		
		# NOTE: The fiber must be created in #update to be used in #update
		#       If it is created in one callback and then called from another:
		#       => FiberError: fiber called across stack rewinding barrier
		
		# As a side effect of using a fiber, you can kill
		# the downloding process in the middle by just
		# closing the Window
		
		# NOTE: Current render speed is ~12 fps while Fiber is active
		#       Not sure if this is a result of Fiber overhead, or download()
		
		@fiber ||= FiberTask.new
		@fiber.resume
		
		
		
		# TODO: use Fiber to create loading bar / spinner to show progress in UI
	end
	
	def draw
		super()
		
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






class FiberTask
	# extend Forwardable
	# def_delegator :@fiber, 
	
	def initialize
	@fiber = Fiber.new do
	
	# === MAIN ===
	current_file = Pathname.new(__FILE__).expand_path
	current_dir  = current_file.parent
	
	Dir.chdir current_dir do
		
		
		Fiber.yield # <----------------
		
		
		# -- parse HTML file and get youtube subscriptions
		in_path  = Pathname.new("./youtube_subscriptions.html").expand_path
		out_path = Pathname.new('./nokogiri_cleaned_data.html').expand_path
		# subscriptions = foo(in_path, out_path) # create debug file to test loading
		subscriptions = foo(in_path) # no debug file
		
		# -- save youtube subscription data to YAML file
		yaml_path = Pathname.new('./data.yml').expand_path
		dump_yaml(subscriptions => yaml_path)
		
		
		# -- use subscription data to find icons for Youtube channels,
		#    and download all of the icons into a folder on the disk
		
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
		
		
		
		
		# -- reformat: [channel_name, link, icon_filepath]
		#    (going forward, icons will be accessed via filepaths, not URLs)
		local_subscriptions = 
		  subscriptions.zip(icon_filepaths).collect do |data, icon_filepath|
		    {
		      'channel-name'  => data['channel-name'],
		      'link'          => data['link'],
		      'icon-filepath' => icon_filepath,
		      'entry-count'   => data['entry-count']
		    }
		  end
		  
		# save data to file
		yaml_path = Pathname.new('./local_data.yml').expand_path
		dump_yaml(local_subscriptions => yaml_path)
		
		
		# TODO: separate raw data files from intermediates
		#   Makes it a lot easier to clean up later
		#   if the intermediates are restricted to one directory
		
		
		
		# ---------------                          ---------------
		# At this point, youtube URLs and icon links are absolute,
		# rather than being relative to the youtube domain. This 
		# means we are free from thinking about YouTube in any way.
		# ---------------                          ---------------
		
		
		# -- use OpenFrameworks to 'visualize' this data
		
		
		
		# -- allow direct manipulation of the data
		#    (control layout of elements with mouse and keyboard, not code)
		
		
		
		# -- add more YouTube subscriptions without losing existng organization
		
		
		
		
		# -- click on links and go to YouTube pages
		
		
		# require 'irb'
		# binding.irb
	end # close Dir.chdir
	end; end # close Fiber, close #initialize
	
	
	def resume
		# @fiber    possible values: nil, Fiber, :finished
		begin
			if @fiber.nil?
				@fiber = create_fiber()
			elsif @fiber != :finished
				# p @fiber
				# p @fiber.methods
				@fiber.resume
				# @fiber.resume
			end
		rescue FiberError => e
			# Error is thrown when Fiber is dead (no more work)
			# use that as a signal of when to stop
			p e
			@fiber = :finished # if you reset to 'nil', the process loops
		end
	end
	
	
	
	
	
	

	private
	
	
	
	
	
	
	
	# input_path          path to the input HTML file
	# test_output_path    path that Nokogiri can write to, to ensure parsing works
	def foo(input_path, test_output_path=nil)
	  # + open youtube in firefox
	  # + open sidebar
	  # + scroll down to the bottom of all the subscriptions (to load all of them)
	  # + use "inspect" tool
	  # + visually select the "SUBSCRIPTIONS" header
	  # + find the HTML element that contains all subscription links / buttons
	  # + in inspector: right click -> Copy -> Outer HTML
	  # => saved that data to file, and load it up here in Nokogiri
	  doc = open_html_file(input_path)
	  
	  
	  
	  # clean input
	  # + strip whitespace from 'span.guide-entry-count' (the numbers in sidebar)
	  
	  
	  # If a debug output location has been specified,
	  # rewrite this this data back out to file,
	  # so I can see how Nokogiri cleans the data
	  unless test_output_path.nil?
	  File.open(test_output_path, 'w') do |f|
	     f.print doc.to_xhtml(indent:3, indent_text:' ')
	  end
	  end
	  
	  
	  
	  
	  # --- start poking around in the document, trying to get the data we want
	  
	  
	  # Basic document structure
	  # ---
	  # 'ytd-guide-section-renderer'
	    # 'ytd-guide-entry-renderer'
	      # 'a'
	        #  ["text", "yt-icon", "yt-img-shadow", "span", "text", "span", "text"] 
	  
	  
	  
	  # -- this is all the subscriptions, enumerated
	  # main  = doc.css('ytd-guide-section-renderer')
	  # items = doc.css('ytd-guide-section-renderer > div#items')
	  subscription_links = doc.css('ytd-guide-section-renderer > div#items a')
	  
	  # # find out the number of subscriptions
	  # subscription_links.size
	  
	  # subscription_links[0].children.collect{ |x| x.name }
	  #  # => ["text", "yt-icon", "yt-img-shadow", "span", "text", "span", "text"] 
	  
	  
	  
	  
	  # -- get a particular subscription by index
	  # i = 0
	  # sub_data = subscription_links[i].children.reject{ |x| x.name == 'text' }
	  
	  # data = parse_youtube_subscription(sub_data)
	  
	  
	  # -- parse all subscriptions
	  # subscription_links.each_with_index do |sub_link, i|
	  #   sub_data = sub_link.children.reject{ |x| x.name == 'text' }
	  #   puts i
	  #   p parse_youtube_subscription(sub_data)
	  # end
	  
	  subscriptions = 
	    subscription_links.collect do |link|
	      parse_youtube_subscription(link)
	    end
	    
	  return subscriptions
	end
	
	
	
	
	# sub_data[0].attributes['disable-upgrade'] # JSON payload, gives URL to icon
	# # => #<Nokogiri::XML::Attr:0x1257c58 name="disable-upgrade" value="{\"thumbnails\":[{\"url\":\"https://yt3.ggpht.com/-DqhnQ70YsRo/AAAAAAAAAAI/AAAAAAAAAAA/TTVyaxv3Xag/s88-c-k-no-mo-rj-c0xffffff/photo.jpg\"}],\"webThumbnailDetailsExtensionData\":{\"isPreloaded\":true,\"excludeFromVpl\":true}}"> 
	# sub_data[1] # HTML element with the actual icon
	# sub_data[2] # SPAN -> channel name
	# sub_data[3] # SPAN -> 'entry-count'
		
	# figure out the fields inside one subscription
	def parse_youtube_subscription(anchor_tag)
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
	  
	  
	  return data
	end


	def open_html_file(filepath) # => Nokogiri::HTML::Document
	  File.open(filepath) do |f|
	    url      = nil
	    encoding = 'utf-8'
	    Nokogiri::HTML(f, url, encoding) do |config|
	      config.noblanks
	    end
	    # ^ remember to use HTML mode, not XML mode
	  end
	end
	
	
	
	# usage: download(url => output_path)
	def download(args = {})
	  # 
	  # parse arguments
	  # 
	  if args.keys.size == 1 and args.values.size == 1
	    url         = args.keys.first
	    output_path = args.values.first
	  else
	    raise "download() currently only accepts one {URL => location} pair"
	  end
	  
	  # 
	  # perform the download
	  # 
	  
	  # https://stackoverflow.com/questions/2263540/how-do-i-download-a-binary-file-over-http
	  # instead of http.get
	  require 'open-uri'
	  
	  File.open(output_path, "wb") do |saved_file|
	    # the following "open" is provided by open-uri
	    open(url, "rb") do |read_file|
	      saved_file.write(read_file.read)
	    end
	  end
	end

	# usage: dump_yaml(data => output_path)
	def dump_yaml(args = {})
	  # 
	  # parse arguments
	  # 
	  if args.keys.size == 1 and args.values.size == 1
	    data        = args.keys.first
	    output_path = args.values.first
	  else
	    raise "dump_yaml() currently only accepts one {URL => location} pair"
	  end
	  
	  # 
	  # serialize the file
	  # 
	  File.open(output_path, 'w') {|f| f.write data.to_yaml }
	end



end # close FiberTask class definition

