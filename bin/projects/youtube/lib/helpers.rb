



module HelperFunctions
	private
	
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
end



class FiberQueue
	attr_reader :state
	
	def initialize(&block)
		@state = :idle # :idle, :active, :finished
		
		@fiber = Fiber.new do
			block.call()
			 
			Fiber.yield(:finished)
		end
	end
	
	def resume(*args)
		unless @fiber.nil?
			@state = :active
			# p @fiber
			# p @fiber.methods
			out = @fiber.resume(*args)
			# @fiber.resume
			
			if out == :finished
				@state = :finished
				# this output is not a generated value
				# but a signal that we can't generate anything else
				puts "#{self.class}: No more work to be done in this Fiber."
				@fiber = nil
				return nil
			else
				# process the generated value
				return out
			end
		end
	end
end




class Task1 < FiberQueue
	include HelperFunctions
	
	def initialize
		super do
		# === MAIN ===
		current_file = Pathname.new(__FILE__).expand_path
		current_dir  = current_file.parent
		
		Dir.chdir current_dir do
			# note on variable names
			# ---
			# p1   pathway      Performs a sequence of operations / transformations
			# c1   checkpoint   A good place to pause. Saves data on disk for later.
			
			in_path  = Pathname.new("./youtube_subscriptions.html").expand_path
			out_path = Pathname.new('./nokogiri_cleaned_data.html').expand_path
			c1_path  = Pathname.new('./data.yml').expand_path
			c2_path  = Pathname.new('./local_data.yml').expand_path
			
			inputs  = [in_path]
			outputs = [out_path, c1_path, c2_path]
			
			input_time = inputs.collect{ |path| path.mtime }.max # most recent time
			
			flag = 
				outputs.any? do |path|
					# redo the calculation if a file is missing, or any file is out of date
					!path.exist? or path.mtime < input_time
				end
			
			if flag
				# -- parse HTML file and get youtube subscriptions
				# subscriptions = p1(in_path, out_path) # create debug file to test loading
				subscriptions = p1(in_path) # no debug file
				
				
				# save data to file
				dump_yaml(subscriptions => c1_path)
				
				
				Fiber.yield # <----------------
				
				
				# -- use subscription data to find icons for Youtube channels,
				#    and download all of the icons into a folder on the disk,
				icon_filepaths = p2(subscriptions) # yields after every download
				
				
				# -- Associate paths to icons on disk with Youtube channels
				#    reformat: [channel_name, link, icon_filepath]
				#    (going forward, icons will be accessed via filepaths, not URLs)
				local_subscriptions = p3(subscriptions, icon_filepaths)
				
				
				Fiber.yield # <----------------
				
				
				# save data to file
				dump_yaml(local_subscriptions => c2_path)
			end
			
			Fiber.yield c2_path
			
			# TODO: separate raw data files from intermediates
			#   Makes it a lot easier to clean up later
			#   if the intermediates are restricted to one directory
			
			
			
			# ---------------                          ---------------
			# At this point, youtube URLs and icon links are absolute,
			# rather than being relative to the youtube domain. This 
			# means we are free from thinking about YouTube in any way.
			# ---------------                          ---------------
		end # close Dir.chdir
		end
	end
	
	
	private
	
	# input_path          path to the input HTML file
	# test_output_path    path that Nokogiri can write to, to ensure parsing works
	def p1(input_path, test_output_path=nil)
	  # + open youtube in firefox
	  # + open sidebar
	  # + scroll down to the bottom of all the subscriptions (to load all of them)
	  # + use "inspect" tool
	  # + visually select the "SUBSCRIPTIONS" header
	  # + find the HTML element that contains all subscription links / buttons
	  # + in inspector: right click -> Copy -> Outer HTML
	  # => saved that data to file, and load it up here in Nokogiri
	  doc = open_html_file(input_path)
	  
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
	
	
	# -- use subscription data to find icons for Youtube channels,
	#    and download all of the icons into a folder on the disk
	def p2(subscriptions)
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
		
		return icon_filepaths
	end
	
	def p3(subscriptions, icon_filepaths)
		local_subscriptions = 
		  subscriptions.zip(icon_filepaths).collect do |data, icon_filepath|
		    {
		      'channel-name'  => data['channel-name'],
		      'link'          => data['link'],
		      'icon-filepath' => icon_filepath,
		      'entry-count'   => data['entry-count']
		    }
		  end
	end
	
	
end


