# Wait for paths on disk to exist, or variables to be set (become non-nil)
# (variable gating behavior only tested on instance variables)
class Checkpoint
	include HelperFunctions
	
	attr_accessor :save_filepath, :input_paths, :output_paths, :variables
	
	def initialize
		
	end
	
	def gate(&block)
		# Basic error checking
		if @input_paths.nil? or @output_paths.nil? or @variables.nil?
			raise "ERROR: Tried to execute Gate without defining inputs / outputs"
		end
		
		
		# c1) waiting for precondition to be satisfied
			# Failure to specify inputs that can potentially be fulfilled is an error. Ideally, the system should disallow this sort of configuration. If you had a full graph of how the checkpoints connect, you could verify statically that the contracts were fulfilled. This chunk of code to detect the error dynamically should thus eventually be depreciated. Visually displaying / visual manipulation of this graph is a must. Failure to do that gives the sort of ridgid and opaque system seen in Haskell
		puts "Checkpoint #{self.object_id}: Waiting for variables to be set"
		until @variables.call.all?{|x| x != nil }
			Fiber.yield # <----------------
			
			# require 'irb'
			# binding.irb
		end
		
		puts "Checkpoint #{self.object_id}: Waiting for input paths to exist"
		until @input_paths.values.all? { |path| path.exist? }
			Fiber.yield # <----------------
			
			require 'irb'
			binding.irb
		end
		
		
		puts "Checkpoint #{self.object_id}: Inputs ready."
		
		# c2) have the precondition we need, now create the data
		input_time = @input_paths.values.collect{ |path| path.mtime }.max 
		# ^ most recent time
		
		flag = 
			@output_paths.values.any? do |path|
				# run the callback if a file is missing,
				# or any file is out of date
				!path.exist? or path.mtime < input_time
			end
		
		
		# NOTE: No need to pass variables to block
		if @save_filepath.nil?
			# 
			# there is no filepath. always run the block, and don't save state
			# 
			return block.call(@input_paths, @output_paths)
		else
			# 
			# filepath for saving intermediate values specified
			# 
			
			# c3) data was already generated, load it from the disk
			# c4) data was generated, but is out of date
			if !flag and @save_filepath.exist?
				puts "Checkpoint #{self.object_id}: data loaded!"
				return YAML.load_file(@save_filepath)
				
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
				data = block.call(@input_paths, @output_paths)
				
				# ... and save data to file
				puts "Checkpoint #{self.object_id}: saving data to disk"
				dump_yaml(data => @save_filepath)
				
				return data
			end
		end
		
		
		
	end
end
