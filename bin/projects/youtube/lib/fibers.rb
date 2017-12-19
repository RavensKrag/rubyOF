class FiberQueue
	attr_reader :state
	
	def initialize(&block)
		@state = :idle # :idle, :active, :finished
		
		@fiber = Fiber.new do |*inital_args|
			block.call(*inital_args)
			
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
	
	def transfer(*args)
		unless @fiber.nil?
			@state = :active
			# p @fiber
			# p @fiber.methods
			out = @fiber.transfer(*args)
			# @fiber.transfer
			
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



class Window < RubyOF::Window
	include HelperFunctions
	
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
