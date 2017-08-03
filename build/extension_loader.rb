# Function to help you load c extension dynamic libraries
# (Predicated on the need for complex editing of the path on Windows, but I'm not actually sure if that is actually necessary on not. Needs testing.)

def load_c_extension_lib(absolute_path)
	# Stolen from Gosu's code to load the dynamic library
		# TODO: check this code, both here and in the main build, when you actually try building for Windows. Is it neccessary? Does it actually work? It's rather unclear. (I don't think I'm defining RUBY_PLATFORM anywhere, so may have to at least fix that.)
	# if defined? RUBY_PLATFORM and
	# %w(-win32 win32- mswin mingw32).any? { |s| RUBY_PLATFORM.include? s } then
	# 	ENV['PATH'] = "#{File.dirname(__FILE__)};#{ENV['PATH']}"
	# end
	
	raise "ERROR: Must load c-extension using absolute path. Path given was: '#{absolute_path}'" unless Pathname.new(absolute_path).absolute?
	
	
	begin
		require absolute_path
	rescue LoadError => e
		raise LoadError, "ERROR: c-extension dynamic library not found @ '#{absolute_path}'" 
		# NOTE: Can't detect presense of dynamic lib using File.exist? because the file extension is ommitted (deliberately) for cross-platform compatability (extension changes depending on platform)
	end
end
