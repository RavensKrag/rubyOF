# Need to rebind code, but keep data exactly the way it is in memory,
# because when I have a full history of states for Space I can roll
# back to, I don't want to have to pay the cost of full serialization
# every time I refresh the code.

# The idea is to dynamically reload the core part of the code base.
# From there, any reloading of additional types or data is
# 

require 'state_machine'



module LiveCoding

class Loader
	# NOTE: Save @inner, not the entire wrapper. This means you can move the defining code to some other location on disk if you would like, or between computers (system always uses absolute paths, so changing computer would break data, which is pretty bad)

	# remember file paths, and bind data	
	def initialize(class_constant_name,
		header:, body:, save_directory:, method_contract:
	)
		super()
		# Have to call super() to initialize state_machine
		# if you don't, you get a symbol collision on '#draw'
		# because that is the method used to visualize the state machine.
		
		
		puts "setting up Live Coding environment"
		
		
		@klass_name  = class_constant_name
		@save_file   = save_directory/'data.yml'
		@method_contract = method_contract
		
		
		@files = {
			:header => FilePair.new(header),
			:body   => FilePair.new(body)
		}
		
		# dynamic_load will change @execution_state
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
	
	def font_color=(color)
		@wrapped_object.font_color = color
	end
	
	
	
		
	state_machine :state, :initial => :running do
		state :running do
			# reload code as needed
			def update(window)
				puts "loader: update"
				
				
				# -- update files as necessary
				dynamic_load @files[:body]
				
				
				# -- delegate update command
				sym = :update
				protect_runtime_errors do
					if @wrapped_object.nil?
						puts "null handler: #{sym}"
					else
						
						@history.save @wrapped_object
						
						@wrapped_object.send sym, window
					end
				end
			end
			
			def draw(window)
				sym = :draw
				protect_runtime_errors do
					if @wrapped_object.nil?
						puts "null handler: #{sym}"
					else
						@wrapped_object.send sym, window, self.state
					end
				end
			end
		end
		
		# Don't generate new state, but render current state
		# and alllow time traveling. Can also just resume execution.
		state :paused do
			def update(window)
				
			end
			
			def draw(window)
				sym = :draw
				protect_runtime_errors do
					if @wrapped_object.nil?
						puts "null handler: #{sym}"
					else
						@wrapped_object.send sym, window, self.state
					end
				end
			end
		end
		
		# Can't generate new state or resume until errors are fixed.
		# Can also use time traveling to help fix the errors.
		state :error do
			# can't go forward until errors are fixed
			def update(window)
				# puts "error"
			end
			
			def draw(window)
				sym = :draw
				protect_runtime_errors do
					if @wrapped_object.nil?
						puts "null handler: #{sym}"
					else
						@wrapped_object.send sym, window, self.state
					end
				end
			end
		end
		
		
		
		
		# 3 time traveling states:
		# + good timeline      rolling all the way forward, can resume execution
		#                      (original was good, looking for something new)
		# 
		# + doomed timeline    can only resume after successful forecasting
		#                      (original was bad, need something good)
		# 
		# + forecast error     can only resume after successful forecasting
		#                      (very bad - time record has become corrupted)
		state :good_timeline do
			def update(window)
				
			end
			
			# draw onion-skin visualization
			def draw(window)
				
			end
		end
		
		# A failed timeline caused by fairly standard program errors.
		state :doomed_timeline do
			def update(window)
				
			end
			
			# draw onion-skin visualization
			def draw(window)
				
			end
		end
		
		# A failed timeline caused by the time ripples from forecasting.
		state :forecast_error do
			def update(window)
				
			end
			
			# draw onion-skin visualization
			def draw(window)
				
			end
		end
		
		
		
		
		# once you are in this state, the load has succeeded.
		# at this point, you attempt to generate a forecast.
		# if the forecast fails -> :forecast_error (a failed timeline variant)
		state :forecasting do
			# update everything all at once
			# (maybe do that on the transition to this state?)
			def update(window)
				# update the state
				protect_runtime_errors do
					
					
					raise "ERROR: forecasting failed"
				end
				
				
				# transition to time_traveling state,
				# as long as update was successful
				self.start_time_travel()
			end
			
			# draw onion-skin visualization
			def draw(window)
				
			end
		end
		
		
		
		
		# 
		# process errors
		# 
		
		event :runtime_error do
			# regular runtime errors
			transition :running => :error
			
			# tried to forecast, but hit an exception while generating new state
			transition :forecasting => :forecast_error
		end
		
		event :load_error do
			# tried to reload under normal execution conditions, but failed
			transition :running => :error
			transition :paused => :error
			transition :error => :error
			
			
			# tried to forecast, but there was a load error
			transition :good_timeline => :forecast_error
			transition :doomed_timeline => :forecast_error
			transition :forecast_error => :forecast_error
		end
		
		event :successful_reload do
			transition :error => :running
			transition :running => :running
			transition :paused => :paused
			
			transition :doomed_timeline => :forecasting
			transition :good_timeline => :forecasting
			transition :forecast_error => :forecasting
		end
		
		after_transition :on => :successful_reload, :do => :on_reload
		
		
		
		# 
		# standard transitions
		# 
		
		event :pause do
			transition :running => :paused
		end
		
		event :resume do
			transition :paused => :running
			transition :running => :running
		end
		
		
		event :start_time_travel do
			transition :paused => :good_timeline
			transition :error => :doomed_timeline
		end
		
		
		
		# 
		# setup time travel variables
		# 
		
		after_transition :from => :running, :to => :error,
		                 :do => :foo_callback
		after_transition :from => :running, :to => :paused,
		                 :do => :foo_callback
		
		
		
		# # 
		# # after a successful forecast, resume execution
		# # 
		
		# after_transition :from => :running, :to => :forecasting,
		#                  :do => :bar_callback
		
		# after_transition :from => :running, :to => :forecasting,
		#                  :do => :bar_callback
		
		
		
		
		
		after_transition :to => :error, :do => :error_callback
		# block callbacks will execute in the context of StateMachine,
		# where as method callbacks will execute in the context of Loader
		
		
		
	end
	
	def on_reload
		unless @wrapped_object.nil?
			@wrapped_object.regenerate_update_thread!
			@wrapped_object.regenerate_draw_thread!
		end
	end
	
	def error_callback
		puts "------> error detected"
		puts @klass_name
		puts self.class
	end
	
	def foo_callback
		@t_jmp = nil # <- when did we time travel to before forecasting
		@t_end = nil # <- set to whatever the current execution iterator is
	end
	
	# when you forecast a succesful future, you need to change the bounds of time travel: can the forcasted future end sooner than you expect, if it "ends" in success?
		# NO! because the Fiber will run forever, due to the infinite loop at the end.
	def bar_callback
		# @t_jmp = nil # <- when did we time travel to before forecasting
		# @t_end = nil # <- set to whatever the current execution iterator is
		
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
			a = contract
			b = instance_methods
			
			msg = 
			[
			"Failed to bind the class #{klass}",
			"  Class does not respond to all methods specified in the method contract.",
			"  contract: #{a.inspect}",
			"  methods:  #{b.inspect}",
			"  missing methods: #{(a - b).inspect}",
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
		excluded_methods = [:update, :draw]
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
			
			
			self.runtime_error()
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
			
			self.runtime_error()
		else
			self.successful_reload()
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
		# @execution_state = :paused
	end
	
	# Resume normal execution.
	# 
	# This is not the same thing as forecasting, which shows
	# how changes to the past will effect the future. This
	# is just normally executing the code.
	def resume_execution()
		# @execution_state = :running
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
