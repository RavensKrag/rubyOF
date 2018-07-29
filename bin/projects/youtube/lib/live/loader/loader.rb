# Need to rebind code, but keep data exactly the way it is in memory,
# because when I have a full history of states for Space I can roll
# back to, I don't want to have to pay the cost of full serialization
# every time I refresh the code.

# The idea is to dynamically reload the core part of the code base.
# From there, any reloading of additional types or data is
# 

module LiveCoding

class Loader
	# NOTE: Save @inner, not the entire wrapper. This means you can move the defining code to some other location on disk if you would like, or between computers (system always uses absolute paths, so changing computer would break data, which is pretty bad)

	# remember file paths, and bind data	
	def initialize(class_constant_name,
		header:, body:, save_directory:, method_contract:
	)
		puts "setting up Live Coding environment"
		
		
		@klass_name  = class_constant_name
		@save_file   = save_directory/'data.yml'
		@method_contract = method_contract
		
		
		@files = {
			:header => FilePair.new(header),
			:body   => FilePair.new(body)
		}
		
		dynamic_load @files[:header]
		dynamic_load @files[:body]
		
		
		klass = Kernel.const_get @klass_name
		if method_contract_satisfied?(klass, @method_contract)
			setup_delegators(@method_contract)
		end
		
		@wrapped_object = klass.new
		@history = ExecutionHistory.new
	end
	
	# automatically save data to disk before exiting
	def on_exit
		
	end
	
	
	# reload code as needed
	def update
		# puts "update"
		
		
		# -- update files as necessary
		dynamic_load @files[:body]
		
		
		# -- delegate update command
		
		protect_runtime_errors do
			if @wrapped_object.nil?
				puts "null handler: update"
			else
				
				@history.save @wrapped_object
				
				@wrapped_object.update
				
				
			end
		end
	end
	
	
	# NOTE: under this architecture, you can't dynamically change initialization or serialization code - you would have to restart the program if that sort of change is made
	# ^ is this still true?
	
	
	private
	
	
	# 
	# input checking
	# 
	
	def method_contract_satisfied?(klass, contract)
		instance_methods = klass.instance_methods
		
		unless contract.all?{|sym| instance_methods.include? sym }
			a = contract.inspect
			b = instance_methods.inspect
			
			msg = 
			[
			"Failed to bind the following object from #{@file}: #{obj}",
			"  Object returned from lambda does not respond to all methods specified in the method contract.",
			"  contract: #{a}",
			"  methods:  #{b}",
			"  missing methods: #{a - b}",
			].join("\n")
			
			raise msg
		end
		
		return true
	end
	
	
	
	
	
	# 
	# create delegates to all of the methods in @method_contract
	# 
	
	def setup_delegators(method_contract)
		# NOTE: Must use the @wrapped_object instance variable instead of passing as parameter. Otherwise, #setup_delegators needs to be re-run every time a new object is loaded.
		
		# TODO: automate creation of wrappers for methods with names that exist in this wrapper (create all mehtods on module, and then mix it in?)
		
		# --- blacklist some methods from being wrapped,
		#     because they have been handled manually.
		excluded_methods = [:update]
		method_symbols = (method_contract - excluded_methods)
		
		
		# --- make sure :setup isn't part of the method contract
		if method_symbols.include? :setup
			raise WrapperContractError, "Callback object should not declare #setup. Place setup code in the normal #initialize method found in all Ruby objects instead. Fix the method contract and try again."
		end
		
		# --- check for symbol collision
		collisions = self.public_methods + self.private_methods
		if collisions.any?{|sym| method_symbols.include? sym }
			raise WrapperNameCollison.new(
				sym, file, method_contract, method_symbols
			)
		end
		
		# --- create the acutal delegators
		method_symbols.each do |sym|
			meta_def sym do |*args|
				protect_runtime_errors do
					if @wrapped_object.nil?
						# puts "null handler: #{sym}"
					else
						@wrapped_object.send sym, *args
					end
				end
			end
		end
	end
	
	class WrapperNameCollison < StandardError
		def initialize(sym, file, method_contract, method_symbols)
			msg = 
				"wrapper / wrapped object method name collision for method '#{sym}' in the contract for callback object from #{file}.\n" +
				"  Full method contract: #{method_contract.inspect}\n" +
				"  Attempting to bind these symbols: #{method_symbols.inspect}\n" +
				"  (To examine where the contract was defined, look further up the stack, to where DynamicObject.new was called."
			super(msg)
		end
	end
	
	class WrapperContractError < StandardError
		def initialize(msg)
			super(msg)
		end
	end
	
	
	
	
	
	# 
	# handle runtime errors
	# 
	
	include ErrorHandler
	
	# If you encounter a runtime error with live coded code,
	# the greater program will continue to run.
	# (centralizing error code from #update and #setup_delegators)
	def protect_runtime_errors # &block
		begin
			yield
		rescue StandardError => e
			# keep execption from halting program,
			# but still output the exception's information.
			print_wrapped_error(e)
			
			pause_execution()
			# ^ stop further execution of the bound @wrapped_object
		end
	end
	
	
	
	
	
	
	
	
	# 
	# dynamically load new code from the disk
	# 
	
	
	class FilePair
		include ErrorHandler
		
		attr_reader :file
		
		def initialize(file)
			@file = file
			@last_time = nil
		end
		
		def update_time
			@last_time = Time.now
		end
		
		def changed?
			# Rake uses File.mtime(path_to_file) to figure out if files are out of date or not. 
				# It also has a constant called Rake::LATE, but I can't figure out how that works.
				# 
				# sources:
					# https://github.com/ruby/rake/blob/master/MIT-LICENSE
					# https://github.com/ruby/rake/blob/master/lib/rake/file_task.rb
			
			
			# Can't figure out how Rake::LATE works, but this works fine.
			
			@last_time.nil? or @file.mtime > @last_time
		end
		
		
		def to_s
			return @file.to_s
		end
	end
	
	
	# load code from the specified file
	# if the file has changed since the last load
	def dynamic_load(file) # FilePair
		begin
			if file.changed?
				puts "live loading #{file}"
				load file.to_s
			end
		rescue SyntaxError, ScriptError, NameError => e
			# This block triggers if there is some sort of
			# syntax error or similar - something that is
			# caught on load, rather than on run.
			
			# ----
			
			# NameError is a specific subclass of StandardError
			# other forms of StandardError should not happen on load.
			# 
			# If they are happening, something weird and unexpected has happened, and the program should fail spectacularly, as expected.
			
			# load failed.
			# corresponding snippets have already been deactivated.
			# only need to display the errors
			
			puts "FAILURE TO LOAD: #{file}"
			
			print_wrapped_error(e)
			
			# revert_data()
			# revert_code()
			pause_execution()
		ensure
			# NOW actually update the timestamp.
			file.update_time
		end
		
		
		
		
		# NOTE: Timestamps updated even when load fails
			# This is actually what you want.
			# If you don't do it this way, then every tick of the main loop,
			# the system will try, and fail, to load the file.
			# This will generate a lot of useless noise in the log.
	end
	
	
	
	
	
	
	
	
	# 
	# history manipulation
	# 
	
	# revert_data()
	# advance_data()
	# revert_execution()
	# pause_execution()
	# forecast()
	
	# revert_code() <-- not avialable yet
	
	
	# Roll data back one step.
	# 
	# A standard undo operation. Paired with revert_execution() 
	# you can achive the time travel effect.
	def revert_data()
		
	end
	
	# Step forward in time by restoring saved data.
	# 
	# A standard redo operation. A combination of undo and redo
	# can be used to scrub the simulation, like how one might
	# scrub an animation or other video. More advanced tech is
	# needed to achieve the time travel effect.
	def advance_data()
		
	end
	
	# Roll back TurnCounter objects, to set execution back in time.
	# 
	# Normally, this operation is paired with rolling back data
	# as well. If you don't revert both execution and data, you
	# can't get the time travel effect.
	def revert_execution()
		
	end
	
	# Prevent TurnCounter objects from stepping forward in time.
	# 
	# This effectively pauses execution, but the main loop will
	# continue to run. This means you can hold just one frame
	# on the screen. That might be useful for testing.
	def pause_execution()
		
	end
	
	# Forcasting creates new execution history, and new data
	# 
	# To use forecast, first perform the following setup:
	# + use revert_data() and revert_execution() to travel back in time
	# + use pause_execution() to let the system render just that one state
	# now you can use forecast.
	# -> Call forecast() to re-simulate all time points from where 
	#    you have paused, up to the end of observed time, using new code.
	#    A naieve implementation will clobber the previous data and execution
	#    state, which may not be what you want.
	#    Saving previous data may be useful for comparison, but that
	#    feature is not present in Bret Victor's original example.
	#    "Inventing on Principle"   https://vimeo.com/36579366
	# -> Forecast creates graphical state. Not sure how to handle that yet.
	def forecast()
		
	end
	
	# (I can't do this right now. This would involve version control.)
	def revert_code()
		
	end
	
	
	
	# Deactivate an active instance of a Snippet
	# (only save data when you have a reasonable guarantee it will be safe)
	# (better to roll back a little, than to save bad data)
	def unload(kill:false)
		puts "Unloading: #{@file}"
		
		unless @wrapped_object.nil?
			@wrapped_object.on_exit()
			if kill
				# (kill now: dont save data, as it may be corrupted)
				
			else
				# (safe shutdown: save data before unloading)
				data = @wrapped_object.save
			end
			
			@wrapped_object = nil
		end
	end
	
	
	
	
	
	
	# Render mulitple time points to the same window, visualizing time as space.
	# 
	# The current time point should be solid, and time points in the 
	# future and in the past should be semi transparent.
	# Consider coloring forward and back timepoints in some distingushing way.
	# (e.g. backward in time is blue, and forward in time in red)
	# 
	# ToonBoom: backward = red; forward = green
	# https://www.toonboom.com/resources/video-tutorials/video/onion-skin-0
	# 
	# Modo:    backward = green; forward = blue		(customizable per entity)
	# http://modo.docs.thefoundry.co.uk/modo/801/help/pages/animation/ActorActionPose.html
	def render_onion_skin
		
	end
	
	def render_standard_world
		
	end
	
	def render_ui
		
	end
	
	
	
end

end
