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
	
	# Turn a strcing into a Pathname, and expand to the full path
	def path(input_filepath)
		Pathname.new(input_filepath).expand_path
	end
end
