class Checkpoint
	attr_accessor :save_filepath, :inputs, :outputs
	
	def initialize
		
	end
	
	def gate(&block)
		# Basic error checking
		if @inputs.nil? or @outputs.nil?
			raise "ERROR: Tried to execute Gate without defining inputs / outputs"
		end
		
		
		# c1) waiting for precondition to be satisfied
			# Failure to specify inputs that can potentially be fulfilled is an error. Ideally, the system should disallow this sort of configuration. If you had a full graph of how the checkpoints connect, you could verify statically that the contracts were fulfilled. This chunk of code to detect the error dynamically should thus eventually be depreciated. Visually displaying / visual manipulation of this graph is a must. Failure to do that gives the sort of ridgid and opaque system seen in Haskell
		puts "Checkpoint: Waiting for inputs to be satisfied"
		until @inputs.values.all? { |path| path.exist? }
			Fiber.yield # <----------------
			
			require 'irb'
			binding.irb
		end
		
		puts "Checkpoint: Inputs ready."
		
		# c2) have the precondition we need, now create the data
		input_time = @inputs.values.collect{ |path| path.mtime }.max 
		# ^ most recent time
		
		flag = 
			@outputs.values.any? do |path|
				# run the callback if a file is missing,
				# or any file is out of date
				!path.exist? or path.mtime < input_time
			end
		
		# c3) data was already generated, load it from the disk
		# c4) data was generated, but is out of date
		if flag
			# If callback needs to be run, then run it...
			data = block.call(@inputs, @outputs)
			
			# ... and save data to file
			puts "update: saving data to disk"
			dump_yaml(data => @save_filepath)
			
			return data
		else
			# otherwise, load the data from the disk
			puts "update: data loaded!"
			return YAML.load_file(@save_filepath)
			
			# NOTE: If you use Pathname with YAML loading, the type will protect you.
			# YAML.load() is for strings
			# YAML.load_file() is for files, but the argument can still be a string
			# but, Pathname is a vaild type *only* for load_file()
				# thus, even if you forget what the name of the method is, at least you don't get something weird and unexpected?
				# (would be even better to have a YAML method that did the expected thing based on the type of the argument, imo)
				# 
				# Also, this still doesn't help you remember the correct name...
		end
		
		
	end
end
