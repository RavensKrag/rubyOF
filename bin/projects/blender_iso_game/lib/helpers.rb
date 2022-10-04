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
	
	
	
	# Run the block, and save the results to a file
	# If the block has to be run again, just load data from file instead.
	# (If file exists, use cached data.)
	# (Otherwise, run block and then save to disk)
	def cache(filepath, &block)
		# c3) data was already generated, load it from the disk
		# c4) data was generated, but is out of date
		if filepath.exist?
			puts "Checkpoint #{self.object_id}: data loaded!"
			return YAML.load_file(filepath)
			
			# NOTE: If you use Pathname with YAML loading, the type will protect you.
			# YAML.load() is for strings
			# YAML.load_file() is for files, but the argument can still be a string
			# but, Pathname is a vaild type *only* for load_file()
				# thus, even if you forget what the name of the method is, at least you don't get something weird and unexpected?
				# (would be even better to have a YAML method that did the expected thing based on the type of the argument, imo)
				# 
				# Also, this still doesn't help you remember the correct name...
		else
			# If callback needs to be run, then run it...
			data = block.call()
			# ... save data to file for next time,
			dump_yaml(data => filepath)
			# ... and return the data from memory
			return data
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
	  
	  return output_path
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
	  
	  if output_path.nil? || !output_path.is_a?(String) || !output_path.is_a?(Pathname)
	  	raise "ERROR: expected data => output_path, where output_path is a String or Pathname, but recieved #{output_path.inspect}"
	  end
	  
	  # 
	  # serialize the file
	  # 
	  File.open(output_path, 'w') {|f| f.write data.to_yaml }
	end
	
	# Turn a strcing into a Pathname, and expand to the full path
	def path(input_filepath)
		Pathname.new(input_filepath).expand_path
	end
end
