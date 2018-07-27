require 'pathname'
require Pathname.new(__FILE__).dirname + ('inspection_mixin')


module LiveCoding

# Watch one file, which defines an object,
# and load that dynamic definition whenever
# the file is changed. Instances of DynamicObject
# should delegate a set of methods to the
# wrapped object. Those methods are specified by a
# parameter passed during initialization. (array of symbols)
# 
# (provides a live-coding environment)
# 
# WARNING: Loads file using 'eval'. Make sure to control who has
#          the ability to write the file being watched.
class DynamicObject
	include LiveCoding::InspectionMixin
	
	# NOTE: Always use Pathname to handle file paths
	
	# TODO: consider type checking the arguments and providing useful error messages
	def initialize(
	    window,
	    save_directory:,
	    dynamic_code_file:,
	    parameters:,
	    method_contract:[]
	)
		if save_directory.nil?
			raise "ERROR: Must specify path to a directory where DynamicObject can serialize data using the 'save_directory' keyword argument."
		end
		
		if dynamic_code_file.nil?
			raise "ERROR: Must specify path to the file to be watched using the 'filepath' keyword argument."
		end
		
		if parameters.nil?
			warn "Warning: No parameters provided to dynamic code loading from #{dynamic_code_file}. Specify parameters using the keyword argument 'parameters' as necessary. (Pack all params into one Array)"
		end
		
		
		
		
		@window = window
		@save_directory = Pathname.new(save_directory).expand_path
		
		# File in which @wrapped_object is declared
		@file = Pathname.new(dynamic_code_file).expand_path
		
		# Last time the file was loaded
		# (nil means file was never loaded)
		@last_load_time = nil
		
		# parameters to pass to the wrapper object on setup
		@parameters = parameters
		
		# methods (messages) to be delegated to @wrapped_object
		@contract = method_contract
		
		# these are the things being wrapped
		@wrapped_object = nil
		# ^ instance of an anonymous class. provides callbacks
		
		setup_delegators(@contract) # wraps @wrapped_object
		# NOTE: As #setup_delegators uses the @wrapped_object variable to get the wrapped object, #setup_delegators can be run even before @wrapped_object has bound to an actual object.
	end
	
	# first load of the wrapped object, and first initialization
	def setup(*args)
		load_wrapped_object() # => @wrapped_object
		# ^ runs #setup on the new object
	end
	
	# update the state of this object, and then delegate to the #update
	# on the wrapped object if that is a necessary part of the contract.
	# 
	# NOTE: Most of the time, you want to read the state transition callbacks
	#       and ignore the complexity of this method.
	def update(*args) # args only necessary for delegation
		load_wrapped_object() # => @wrapped_object
		
		# delegate to wrapped object if :update is part of the contract
		if !@wrapped_object.nil? and @contract.include? :update
			# TODO: maybe memoize the invariant? could get bad if @contact is long
			
			protect_runtime_errors do
				@wrapped_object.update *args
			end
		end
	end
	
	def on_exit
		unload(kill:false)
	end
	
	
	
	private
	
	# If you encounter a runtime error with live coded code,
	# the greater program will continue to run.
	# (centralizing error code from #update and #setup_delegators)
	def protect_runtime_errors # &block
		begin
			yield
		rescue StandardError => e
			# keep execption from halting program,
			# but still output the exception's information.
			process_snippet_error(e)
			
			unload(kill:true)
			# ^ stop further execution of the bound @wrapped_object
		end
	end
	
	# Delegate methods from the 'contract' to the wrapped object
	# (handle the #update method separately)
	# 
	# + Never delegate to an unbound @wrapped_object.
	# + Handle runtime errors in a special way,
	#   as the default handling crash the whole system.
	# + Error when the contract contains a method with the same name
	#   as a method in this wrapper. That requires manual handling.
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
					unless @wrapped_object.nil?
						if @wrapped_object.respond_to? sym
							@wrapped_object.send sym, *args 
						else
							warn "WARNING: class declared in #{@file} does not respond to '#{sym}'"
						end
					end
				end
			end
		end
	end
	
	
	# This method is the only part in the codebase
	# where @wrapped_object should be set
	# (plus #initialize, which only set it to nil)
	def load_wrapped_object
		# load file if it has been changed
		if file_changed?(@file, @last_load_time)
			puts "loading snippets..."
			
			# TODO: Figure out what happens if a file is simply deleted. Need to make sure that if a file is deleted, the Snippets in memory are deleted as well.
			
			# TODO: Figure out how to guard against files that have extra code in them: things that lie outside the assumed proc->Object structure (arbitrary code vuln)
			
			begin
				# try to load lambda from file into one variable
				data = binding.eval File.read(@file.to_s), @file.to_s
				
				if data.nil?
					# no snippet declared in file.
					# (surrounding lambda was not declared / declared improperly)
					
					# It is possible that an existing type was invalidated,
					# or that no vaild type was ever declared in this file.
					
					if @wrapped_object.nil?
						# invalid -> invalid
						# NO-OP
						
						puts "Error in #{@file}: Could not perform initial load."
					else
						# valid -> invalid
						unload(kill:false)
						
						puts "Error in #{@file}: Tried to replace valid code with invalid code."
					end
				elsif data.is_a? Proc
					# Want to detect a lambda that returns an Object
					# We know at this stage that the container is as expected,
					# but whether or not the Object is proper will be checked
					# in #load / #reload and not here.
					
					# this type was loaded correctly.
					puts "Read dynamic code from #{@file}"
					
					# By this point, you know you're dealing with a singular class.
					# As long as only this code path sets @wrapped_object,
					# only one snippet will be loaded per file.
					
					if @wrapped_object.nil?
						# class loaded, no instance yet
						# none -> valid
						
						# if new type
						load(data)
					else
						# class loaded, already have an instance
						# valid ---reload--> valid
						
						# if a type from this file already exists
						reload(data)
					end
				else
					# Something unexpected happened.
					# This is bad.
					raise "Problem in #{@file}. Expected the file to define a lambda that returns a Object instance. Instead, recieved the following: #{data.inspect}"
				end
				
				# At this point, class was loaded successfully.
				# Will instatiate later.
			# -------------
			rescue ScriptError, NameError => e
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
				
				puts "FAILURE TO LOAD: #{@file}"
				
				process_snippet_error(e)
			end
			
			
			# NOW actually update the timestamp.
			@last_load_time = Time.now
			# NOTE: Timestamps updated even when load fails
				# This is actually what you want.
				# If you don't do it this way, then every tick of the main loop,
				# the system will try, and fail, to load the file.
				# This will generate a lot of useless noise in the log.
		end
	end
	
	
	# --- forwards chaining approach ---
	# replacement cases: (when to allocate a new thing)
		# constraint inactive
		# constraint active, and file has changed
		# load failed
		
	# --- backwards chaining approach
	# how can it fail?
		# fail to load
			# inactive code replaced by active code
			# active code replaced by inactive code
		# crash while running
			# active code crashes -> deactivate the code
			# active code -> replace with new code -> crash -> deactivate
	
	
	# --- state transition callbacks
	
	# Activate an instance of a bound Snippet
	def load(proc)
		begin
			# run the lambda to get the bound Object
			obj = proc.call()
			
			
			# TODO: move this code into #load, so that it is properly guarded against any sort of exception that may arise.
			
			# --- make sure the object you want to bind behaves as expected
			if obj.nil?
				raise "Problem in #{@file}. Expected the file to define a lambda that returns a Object instance. The lambda was properly defined, but it's return was nil."
			end
			
			unless @contract.all?{|sym| obj.respond_to? sym }
				a = @contract.inspect
				b = obj.methods.inspect
				
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
			# ------
			
			
			
			obj.setup(@window, @save_directory, @parameters)
			puts "Loaded: #{@file}"
			
			
			
			@wrapped_object = obj
		rescue StandardError => e
			process_snippet_error(e)
			
			# If there's a problem, you need to get rid of the class that's causing it,
			# or errors will just stream into STDOUT, which is very bad.
			unload(kill:true)
			# (need to kill because #setup may have corrupted the state)
			
			# distinguish between 'safe shutdown' unloading, and 'kill this now' unloading. Safe shutdown needs to save state. Kill now should never save state (state is lkely to be corrupted.)
		ensure
			# always do this stuff
		end
	end
	
	# Deactivate an active instance of a Snippet
	# (only save data when you have a reasonable guarantee it will be safe)
	# (better to roll back a little, than to save bad data)
	def unload(kill:false)
		puts "Unloading: #{@file}"
		
		unless @wrapped_object.nil?
			@wrapped_object.cleanup()
			if kill
				# (kill now: dont save data, as it may be corrupted)
				
			else
				# (safe shutdown: save data before unloading)
				@wrapped_object.serialize(@save_directory)
			end
			
			@wrapped_object =  nil
		end
	end
	
	# Replace running Snippet classes with updated versions
	# (binds should always happen before loads)
	# NOTE: Reload should NOT be implemented with a combination of load / unload.
	#       (1) you need different debug information.
	#       (2) reloading involves transplanting data from the old instance, to the new one.
	def reload(obj)
		# (each time a Snippet is reloaded, the class ID will change)
		
		# NOTE: Sometimes this replaces working code with broken code.
		#       That's fine. Always want what's current, even if it's broken.
		
		# ASSUME: Only one class definition per file.
		# ^ This check is enforced above, after loading new files.
		
		
		puts "Reloading Snippet defined in: #{@file}"
		print "  "
		unload(kill:false)
		print "  "
		load(obj)
		
		# Snippets need to be anonymous, because that allows all contained
		# constants to easily be thrown away (GCed) when new versions are loaded.
		# The Object.new -> metaclass style allows both contained constants,
		# and contaned Class declarations to be completely swept away on reload.
		
		# (TODO: source the sinatra live reload article, and my personal experiments with constant binding)
		
		
		# NOTE: Now that @file and @save_directory are being saved on the DynamicObject wrapper class, instead of on the callback instance, you likely don't have to copy the value of @save_directory from the old instance. This means that #reload and #load are exactly the same.
		
		
		# TODO: document that methods like #bind, which are not part of the method contract passed to the wrapper object, are nontheless still a part of the required interface for the wrapped object.
		# (the method #bind in particular may not longer be relevant, but this general idea still applies)
		
	end
	
	
	# TODO: define set equality - two items are equal if they load from the same file
	
	
	
	
	# --- private helpers ---
	
	def file_changed?(file, last_time)
		# Rake uses File.mtime(path_to_file) to figure out if files are out of date or not. 
			# It also has a constant called Rake::LATE, but I can't figure out how that works.
			# 
			# sources:
				# https://github.com/ruby/rake/blob/master/MIT-LICENSE
				# https://github.com/ruby/rake/blob/master/lib/rake/file_task.rb
		
		
		# Can't figure out how Rake::LATE works, but this works fine.
		
		last_time.nil? or file.mtime > last_time
	end
	
	
	# error handling helper
	def process_snippet_error(e)
		# process_runtime_error(package, e)
		puts "KABOOM!"
		
		# everything below this point deals only with the execption object 'e'
		
		
		# FACT: Proc with instance_eval makes the resoultion of e.message very slow (20 s)
		# FACT: Using class-based snippets makes resolution of e.message quite fast (10 ms)
		# ASSUME: Proc takes longer to resolve because it has to look in the symbol table of another object (the Window)
		# --------------
		# CONCLUSION: Much better for performance to use class-based snippets.
		
		Thread.new do
			# NOTE: Can only call a fiber within the same thread.
			
			t1 = RubyOF::Utils.ofGetElapsedTimeMillis
			
			out = [
				# e.class, # using this instead of "message"
				# e.name, # for NameError
				# e.local_variables.inspect,
				# e.receiver, # this might actually be the slow bit?
				e.message, # message is the "rate limiting step"
				e.backtrace
			]
			
			# p out
			puts out.join("\n")
			
			
			t3 = RubyOF::Utils.ofGetElapsedTimeMillis
			dt = t3 - t1
			puts "Final dt: #{dt} ms"
			puts ""
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
end


# NOTE: Neither archaeopteryx nor Banjo check to see if they need to reload the files: they just always reload.
		
# archaeopteryx dev references ChucK, and now uses Clojure (with overtone)
# From the Readme:
	# Archaeopteryx differs from projects like ChucK, Supercollider, PD, Max/MSP and OSC in a fundamental way. Archaeopteryx favors simplicity over power, and ubiquitous protocols over any other kind.

# https://github.com/gilesbowkett/archaeopteryx
# https://github.com/gilesbowkett/archaeopteryx/blob/master/eval_style.rb
	# @loop = Arkx.new(:clock => $clock, # rename Arkx to Loop
	#                  :measures => $measures,
	#                  :logging => false,
	#                  :evil_timer_offset_wtf => 0.2,
	#                  :generator => Rhythm.new(:drumfile => "db_drum_definition.rb",
	#                                           :mutation => $mutation))
	# @loop.go
# https://github.com/gilesbowkett/archaeopteryx/blob/master/lib/arkx.rb
# https://github.com/gilesbowkett/archaeopteryx/blob/master/live/db_drum_definition.rb
# https://github.com/gilesbowkett/archaeopteryx/blob/master/lib/rhythm.rb

# https://github.com/dabit/banjo/blob/master/lib/banjo.rb
	# Banjo::Channel.channels.each do |klass|
	# 	channel = klass.new
	# 	channel.perform
	# end
# https://github.com/dabit/banjo/blob/master/lib/banjo/channel.rb





# NOTE: Under the current paradigmn, anyone who has write access to the Snippets folder can run arbitrary code on my machine. That's potentially pretty bad. I suppose require_all has a similar vulnerability? I don't actually know what the "foreign code" sensibility is for interpreted languages.
# Could potentially sandbox the loading? Not sure that this is necessary.
# Should really learn more about security so I don't have this sort of question.
	# It seems even the ImageMagick attack was generally only a problem for servers that provide online image conversion:
	# https://nakedsecurity.sophos.com/2016/05/04/is-your-website-or-blog-at-risk-from-this-imagemagick-security-hole/




# TODO: Eventually replace this with a smarter scheme for turning things on.
# Oh, if you have a smarter mechanism here, that might close the "security problem"?
# Actually no, the code can still run silently on load.
# It doesn't have to be GUI.

# The new system makes it more obvious that dangerous things are happening.
# Part of this is using "eval" rather than "load"
# The new way is also genuinely less bad.
# 
# Now CodeLoader controlls all loading,
# as opposed to old global method style,
# where loading could happen at any time, from any part of the code base.


# TODO: some mechanism for "sleeping" snippets. Don't always need to run every frame.


end
