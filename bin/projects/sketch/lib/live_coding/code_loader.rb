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
	    method_contract:[]
	)
		if save_directory.nil?
			raise "ERROR: Must specify path to a directory where DynamicObject can serialize data using the 'save_directory' keyword argument."
		end
		
		if dynamic_code_file.nil?
			raise "ERROR: Must specify path to the file to be watched using the 'filepath' keyword argument."
		end
		
		
		@window = window
		@save_directory = Pathname.new(save_directory).expand_path
		
		# File in which @wrapped_object is declared
		@file = Pathname.new(dynamic_code_file).expand_path
		
		# Last time the file was loaded
		# (nil means file was never loaded)
		@last_load_time = nil
		
		# methods (messages) to be delegated to @wrapped_object
		@contract = method_contract
		
		# these are the things being wrapped
		@wrapped_object = nil
		# ^ instance of an anonymous class. provides callbacks
		
		
		setup_delegators(@wrapped_object, @contract)
	end
	
	# first load of the wrapped object, and first initialization
	def setup(*args)
		load_wrapped_object() # => @wrapped_object
		# ^ calls klass.new --> runs #initialize on the new object 
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
			@wrapped_object.update *args
		end
	end
	
	
	
	private
	
	
	# Delegate methods from the 'contract' to the wrapped object
	# (handle the #update method separately)
	# 
	# + Never delegate to an unbound @wrapped_object.
	# + Handle runtime errors in a special way,
	#   as the default handling crash the whole system.
	# + Error when the contract contains a method with the same name
	#   as a method in this wrapper. That requires manual handling.
	def setup_delegators(target_object, method_contract)
		# TODO: automate creation of wrappers for methods with names that exist in this wrapper (create all mehtods on module, and then mix it in?)
		
		# --- blacklist some methods from being wrapped,
		#     because they have been handled manually.
		excluded_methods = [:update]
		method_symbols = (method_contract - excluded_methods)
		
		
		# --- check for symbol collision
		if method_symbols.include? :setup
			raise WrapperContractError, "Callback object should not declare #setup. Place setup code in the normal #initialize method found in all Ruby objects instead. Fix the method contract and try again."
		end
		
		collisions = self.public_methods + self.private_methods
		if collisions.any?{|sym| method_symbols.include? sym }
			raise WrapperNameCollison.new(
				sym, file, method_contract, method_symbols
			)
		end
		
		# --- create the acutal delegators
		method_symbols.each do |sym|
			meta_def sym do |*args|
				begin
					unless target_object.nil?
						if target_object.respond_to? sym
							target_object.send sym, *args 
						else
							warn "WARNING: class declared in #{@file} does not respond to '#{sym}'"
						end
					end
				rescue StandardError => e
					# keep execption from halting program,
					# but still output the exception's information.
					process_snippet_error(e)
					unload() # stop further execution of the bound @wrapped_object
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
			
			begin
				# src: http://stackoverflow.com/questions/6864319/ruby-how-to-return-from-inside-eval
				klass =
					lambda{
						 binding.eval File.read(@file.to_s), @file.to_s
					}.call()
				# wrap eval in a lambda that is immediately called.
				# This way, a "return" from inside any Snippet definition
				# will kick out of that subsystem, and skip the binding of that Snippet.
				# (in that case, klass = nil)
				
				if klass.nil?
					# no class declared in file.
					
					# It is possible that an existing type was invalidated,
					# or that no vaild type was ever declared in this file.
					
					
					if @wrapped_object.nil?
						# invalid -> invalid
						# NO-OP
						@wrapped_object = nil
					else
						# valid -> invalid
						@wrapped_object = unload klass
					end
				elsif klass.is_a? Class
					# class declared.
					# this type was loaded correctly.
					
					puts "Read Snippet Class definiton from #{@file}"
					
					# By this point, you know you're dealing with a singular class.
					# As long as things get added in here,
					# you can't ever add more than one Snippet class per file.
					
					if @wrapped_object.nil?
						# class loaded, no instance yet
						# none -> valid
						
						# if new type
						@wrapped_object = load klass
					else
						# class loaded, already have an instance
						# valid ---reload--> valid
						
						# if a type from this file already exists
						@wrapped_object = reload klass
					end
				else
					# Something else happened.
					# This is bad.
					raise "#{klass} is not a Class definition. Problem in #{@file}"
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
	def load(klass)
		begin
			snippet = klass.new(@window, @save_directory)
			puts "Loaded: #{@file}"
			
			return snippet
		rescue StandardError => e
			process_snippet_error(e)
			
			# If there's a problem, you need to get rid of the class that's causing it,
			# or errors will just stream into STDOUT, which is very bad.
			unbind()
			
			return nil
		ensure
			# always do this stuff
		end
	end
	
	# Deactivate an active instance of a Snippet
	def unload
		puts "Unloading: #{@file}"
		
		return nil
	end
	
	# Replace running Snippet classes with updated versions
	# (binds should always happen before loads)
	# NOTE: Reload should NOT be implemented with a combination of load / unload.
	#       (1) you need different debug information.
	#       (2) reloading involves transplanting data from the old instance, to the new one.
	def reload(klass)
		# (each time a Snippet is reloaded, the class ID will change)
		
		# NOTE: Sometimes this replaces working code with broken code.
		#       That's fine. Always want what's current, even if it's broken.
		
		# ASSUME: Only one class definition per file.
		# ^ This check is enforced above, after loading new files.
		
		
		puts "Reloading Snippet defined in: #{@file}"
		
		
		
		# Find active Snippets for replacement by their ORIGIN_FILE constant.
		# Can't use the class name, because classes are anonymous.
		# Classes need to be anonymous, because otherwise the global class variables get weird.
		# (For more information, see documentation on the Snippet class, below.)
		
		begin
			# create new instance, rebinding to same data from the old instance
			obj = klass.new(@window, @save_directory)
			
			# save the new instance
			return obj
			
			# TODO: When #bind is implemented, need to rebind to old targets
			
			# NOTE: Now that @file and @save_directory are being saved on the DynamicObject wrapper class, instead of on the callback instance, you likely don't have to copy the value of @save_directory from the old instance. This means that #reload and #load are exactly the same.
			
			# NOTE: reload is NOT the same, as it must dump the state of the old object, and load that state into the new object
				# call dump / load
				# call #setup
				# (normally setup would be called once for the )
			
			# TODO: document that methods like #bind, which are not part of the method contract passed to the wrapper object, are nontheless still a part of the required interface for the wrapped object.
			
		rescue StandardError => e
			process_snippet_error(e)
			
			# If there's a problem, you need to get rid of the class that's causing it,
			# or errors will just stream into STDOUT, which is very bad.
			@bound = nil
			
			return nil
		ensure
			# always do this stuff
		end
	end
	
	
	
	
	
	
	
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







require 'set' # needed for fast removal

class CodeLoader
	# Every time this file is reloaded, this variable is reset without warning.
	puts "CodeLoader was loaded"
	
	
	# TODO: some mechanism for "sleeping" snippets. Don't always need to run every frame.
	
	@@save_directory = "/home/ravenskrag/Experiments/RubyCPP/Oni/lib/projects/Scope/bin/data/snippet_data/"
	# establish variables
	def initialize(window)
		@window = window
		
		@bound  = Array.new
		@active = Array.new
		
		
		
		# --- setup the basic livecoding stuff
		livecoding_libs = Pathname.new(__FILE__).expand_path.dirname
		@livecode_dir = livecoding_libs/'code'
		
		@last_livecode_load_time = nil
	end
	
	
	
	
	# For convience: make sure one instance of each bound Snippet type is active.
	# (may be hidden, but should be in memory)
	# When a Snippet is unbound, it should no longer be in memory.
	def update
		invalid_types, new_types, updated_types = parse()
		
		
		invalid_types.each do |snippet_class|
			unbind snippet_class
			unload snippet_class
		end
		
		new_types.each do |snippet_class|
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
			bind snippet_class # NOTE: #bind will unbind the old definition
			load snippet_class
		end
		
		updated_types.each do |snippet_class|
			bind   snippet_class # NOTE: #bind will unbind the old definition
			reload snippet_class
		end
	end
	
	
	
	
	# Execute all active Snippets, by running Snippet#call on each and every Snippet.
	def run
		# actually run the snippets,
		# and deal with any errors that may arise.
		@active.each do |snippet|
			begin
				snippet.call
			rescue StandardError => e
				snippet.hide
				process_snippet_error(e)
			ensure
				# always do this stuff
				
			end
		end
		
		# 2.4.0 :001 > SyntaxError
		#  => SyntaxError 
		# 2.4.0 :002 > SyntaxError.superclass
		#  => ScriptError 
		# 2.4.0 :003 > SyntaxError.superclass.superclass
		#  => Exception 
		# 2.4.0 :004 > SyntaxError.superclass.superclass.superclass
		#  => Object 
		# 2.4.0 :005 > 


		
		# 2.4.0 :001 > NameError
		#  => NameError 
		# 2.4.0 :002 > NameError.superclass
		#  => StandardError 
		# 2.4.0 :003 > NameError.superclass.superclass
		#  => Exception 
		# 2.4.0 :004 > NameError.superclass.superclass.superclass
		#  => Object 
	end
	
	
	
	
	
	
	
	
	
	
	private
	
	# load all Snippet definitions from files into memory
	def parse
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
		
		
		# puts "==== Trying to load snippets from file into data"
		
		# --- load new files every game tick
		invalid_types   = Array.new
		new_types       = Array.new
		updated_types   = Array.new
		
		update_timestamp = false # don't actually change timestamp until the end
		# ^ If you don't do it this way, then a change to
		#   the dynamic constants file prevents changes to the Snippets
		#   (or vice versa depending on the ordering of the statements).
		
		# ----------
		Dir.chdir @livecode_dir do
			# --- load the actual snippets
			all_snippets = Pathname.glob('./**/*.rb').collect{|x| x.expand_path}
			
			# show all possible files
			# p all_snippets
			
			snippets_to_load = 
				all_snippets.select do |file|
					# Select all snippets the first time, and then only the ones that are updated.
					file_changed?(file)
					
					# NOTE: wanted to updated all snippets when the constants file was reloaded, but the current implementation leads to segfault? Maybe this is related to all the other segfaults that keep happening?
						# not related to the unset method for physics space configuration. That code fails to load, and so is not executing.
				end
			
			# Rake uses File.mtime(path_to_file) to figure out if files are out of date or not. 
			# It also has a constant called Rake::LATE, but I can't figure out how that works.
			# 
			# sources:
				# https://github.com/ruby/rake/blob/master/MIT-LICENSE
				# https://github.com/ruby/rake/blob/master/lib/rake/file_task.rb
			
			
			# show only the files that are actually going to be loaded
			# p snippets_to_load
			
			unless snippets_to_load.empty?
				puts "loading snippets..."
				update_timestamp = true
				
				
				# NOTE: With the new class-based style, load order and execution order are now independent.
				
				# NOTE: Separated visibilty from whether or not something should be loaded / reloaded.
				#       Load / Reload status is now completely self-contained.
				#       No state about loading of files will leak into the Snippet instances.
				
				
				# TODO: Figure out what happens if a file is simply deleted. Need to make sure that if a file is deleted, the Snippets in memory are deleted as well.
				
				snippets_to_load.each do |file|
					categorize(file, invalid_types, new_types, updated_types)
				end
			end
		end # <-- return to previous directory
		# ----------
		
		
		# NOW actually update the timestamp.
		if update_timestamp
			@last_livecode_load_time = Time.now
		end
		
		
		return [invalid_types, new_types, updated_types]
	end
		
		# helper for #parse()
		def file_changed?(file)
			# Can't figure out how Rake::LATE works, but this works fine.
			
			last_time = @last_livecode_load_time
			
			last_time.nil? or File.mtime(file) > last_time
		end
		
		# helper for #parse()
		def categorize(filepath, invalid_types, new_types, updated_types)
			begin
				# src: http://stackoverflow.com/questions/6864319/ruby-how-to-return-from-inside-eval
				klass =
					lambda{
						 binding.eval File.read(filepath.to_s), filepath.to_s
					}.call()
				# wrap eval in a lambda that is immediately called.
				# This way, a "return" from inside any Snippet definition
				# will kick out of that subsystem, and skip the binding of that Snippet.
				# (in that case, klass = nil)
				
				if klass.nil?
					# no class declared in file.
					
					
					# invalid_types <---------
					
					# It is possible that an existing type was invalidated,
					# or that no vaild type was ever declared in this file.
					# 
					# Take care that no nil values enter the 'invalid_types' array.
					
					snippet_type = find_bound_type(filepath)
					invalid_types << snippet_type unless snippet_type.nil?
					
					#   ^ should only be one such file / Snippet class pair.
					# 
					#     Under new eval system, should not be possible
					#     to define more than one Snippet class per file.
					#     However, should still have a check, just in case.
					
				elsif klass.is_a? Class
					# class declared.
					# this type was loaded correctly.
					
					puts "Read Snippet Class definiton from #{filepath}"
					
					
					# new_types, updated_types <---------
					
					# By this point, you know you're dealing with a singular class.
					# As long as things get added in here,
					# you can't ever add more than one Snippet class per file.
					
					if find_bound_type(filepath)
						# if a type from this file already exists
						updated_types << klass
					else
						# else if new type
						new_types << klass
					end
					
				else
					# Something else happened.
					# This is bad.
					raise "#{klass} is not a Class definition. Problem in #{filepath}"
				end
				# TODO: In the future, all classes should be bound, and then only certain classes should actually be instantiated. Not sure how that would happen, though. Where would the commands to instantiate be declared? How would they be edited? What's the point of binding things you're not using?
				
				
				# load successful. will instatiate later.
			rescue ScriptError, NameError => e
				# NameError is a specific subclass of StandardError
				# other forms of StandardError should not happen on load.
				# 
				# If they are happening, something weird and unexpected has happened, and the program should fail spectacularly, as expected.
				
				# load failed.
				# corresponding snippets have already been deactivated.
				# only need to display the errors
				
				puts "FAILURE TO LOAD: #{filepath}"
				
				process_snippet_error(e)
			end
		end
		
			# Find a bound Snippet class by the file in which it is defined.
			# (helper for #categorize(4))
			def find_bound_type(filepath)
				@bound.find{ |old_klass| old_klass::ORIGIN_FILE == filepath }
			end
	
	
	
	# assign constant to collection
	# (this function must be called at the end of each Snippet file)
	def bind(klass)
		puts "Binding: #{klass::ORIGIN_FILE}"
		
		unbind(klass)
		@bound << klass
	end
	
	# Remove the Snippet class definition from the list of avialable types.
	def unbind(klass)
		puts "Unbinding: #{klass::ORIGIN_FILE}"
		
		# Snippet classes are anonymous, so they can't be invalidated by name.
		@bound.delete_if{|old_klass| old_klass::ORIGIN_FILE == klass::ORIGIN_FILE }
	end
	
	
	# --- forwards chaining approach
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
	
	
	# Activate an instance of a bound Snippet
	def load(klass)
		begin
			snippet = klass.new(@window)
			snippet.bind(@@save_directory)
			@active << snippet
			
			puts "Loaded: #{klass::ORIGIN_FILE}"
		rescue StandardError => e
			process_snippet_error(e)
			
			# If there's a problem, you need to get rid of the class that's causing it,
			# or errors will just stream into STDOUT, which is very bad.
			unbind klass
		ensure
			# always do this stuff
		end
	end
	
	# Deactivate an active instance of a Snippet
	def unload(klass)
		puts "Unloading: #{klass::ORIGIN_FILE}"
		
		@active.delete_if{ |snippet| snippet.class == klass }
	end
	
	# Replace running Snippet classes with updated versions
	# (binds should always happen before loads)
	# NOTE: Reload should NOT be implemented with a combination of load / unload.
	#       (1) you need different debug information.
	#       (2) reloading involves transplanting data from the old instance, to the new one.
	def reload(klass)
		#   (each time a Snippet is reloaded, the class ID will change)
		
		# NOTE: Sometimes this replaces working code with broken code.
		#       That's fine. Always want what's current, even if it's broken.
		
		# NOTE: Visiblity is separate from whether or not a type should be replaced.
		
		# ASSUME: Only one class definition per file.
		# ^ This check is enforced above, after loading new files.
		
		
		filepath = klass::ORIGIN_FILE
		
		puts "Reloading Snippet defined in: #{filepath}"
		
		# puts "Number of Snippet types: #{@bound.length}"
		
		
		# Find active Snippets for replacement by their ORIGIN_FILE constant.
		# Can't use the class name, because classes are anonymous.
		# Classes need to be anonymous, because otherwise the global class variables get weird.
		# (For more information, see documentation on the Snippet class, below.)
		
		
		# Display iteration index, so that when you replace mulitple instances,
		# command line output looks noticably different
		# Otherwise you only see class replacements, and its a disorienting flood of data.
		# Need to provide some sort of context.
		@active.each_with_index
		.select{ |snippet, i| snippet.class::ORIGIN_FILE == filepath }
		.each do |snippet, i|
			
			begin
				
				puts "Active snippet index #{i} : Updating #{snippet.class} --> #{klass}"
				# NOTE: ^ This is useful to make sure the data is actually being changed.
				
				obj = klass.new(@window)
				obj.bind(snippet.save_directory)
				@active[i] = obj
				# TODO: When #bind is implemented, need to rebind to old targets
				
			rescue StandardError => e
				process_snippet_error(e)
				
				# If there's a problem, you need to get rid of the class that's causing it,
				# or errors will just stream into STDOUT, which is very bad.
				@bound.delete klass
			ensure
				# always do this stuff
			end
			
		end
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
		end
		
	end
	
	
	
	
	
	public
	
	
	
	# the following functions are used to pass user input into Snippets that require it
	# TODO: Filter snippets based on 
	
	def mouse_moved(x,y)
		@active
		.select{  |snippet|
			snippet.respond_to? :mouse_moved
		}.each do |snippet|
			snippet.send :mouse_moved, x,y
		end
	end
	
	def mouse_pressed(x,y, button)
		@active
		.select{  |snippet|
			snippet.respond_to? :mouse_pressed
		}.each do |snippet|
			snippet.send :mouse_pressed, x,y,button
		end
	end
	
	def mouse_released(x,y, button)
		@active
		.select{  |snippet|
			snippet.respond_to? :mouse_released
		}.each do |snippet|
			snippet.send :mouse_released, x,y,button
		end
	end
	
	def mouse_dragged(x,y, button)
		@active
		.select{  |snippet|
			snippet.respond_to? :mouse_dragged
		}.each do |snippet|
			snippet.send :mouse_dragged, x,y,button
		end
	end
	
	
	
	def mouse_scrolled(x,y, scrollX, scrollY)
		@active
		.select{  |snippet|
			snippet.respond_to? :mouse_scrolled
		}.each do |snippet|
			snippet.send :mouse_scrolled, x,y, scrollX, scrollY
		end
	end
	
	
	
	def window_resized(w,h)
		@active
		.select{  |snippet|
			snippet.respond_to? :window_resized
		}.each do |snippet|
			snippet.send :window_resized, w,h
		end
	end
	
		
end



# NOTE: Don't preserve descendants.
# That's not a default behavior of Ruby, and it's not desirable here.
# There reason to create anonymous classes, is so the constant table doesn't get messed up.
	# If you bind to class constants, then you get warnings on redifinition,
	# and you can't change the parentage of a class.
		# src: http://blog.rkh.im/code-reloading (seems to be the original definitive article)
		# linked from here: http://www.sinatrarb.com/faq.html
	# (not sure if that second one is useful or not, but best to keep options open)
class Code
	class << self
		private
		
		def origin(filepath)
			const_set "ORIGIN_FILE", filepath
		end
	end
	
	origin File.absolute_path(__FILE__)
	
	def inspect
		"<class=#{self.class} @visible=#{@visible}, file=#{self.class.const_get('ORIGIN_FILE')}>"
	end
	
	
	attr_reader :name, :save_directory
	
	def initialize(window, name)
		@window = window
		@name = name
		
		@visible = true
	end
	
	# setup additional variables
	# (will be useful later for constraints)
	def bind(save_directory)
		@save_directory = save_directory
		
	end
	
	# zero argument method. just run based on what data is loaded.
	def call
		return unless visible?
		
		callback()
	end
	
	# function that actually does the work
	def callback
		
	end
	
	def hide
		@visible = false
	end
	
	def show
		@visible = true
	end
	
	def visible?
		return @visible
	end
end

# class Snippet
# 	# sources:
# 		# https://www.youtube.com/watch?v=CuKQ--FzGmk
# 		# https://github.com/dabit/banjo/blob/master/lib/banjo/channel.rb
# 	def self.channels
# 		@channels ||= []
# 	end

# 	def self.inherited(child)
# 		channels << child
# 	end

# end


end
