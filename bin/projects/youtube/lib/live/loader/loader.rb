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
	include RubyOF::Graphics
	
	
	attr_accessor :time_travel_i
	
	# NOTE: Save @inner, not the entire wrapper. This means you can move the defining code to some other location on disk if you would like, or between computers (system always uses absolute paths, so changing computer would break data, which is pretty bad)

	# remember file paths, and bind data	
	def initialize(window, class_constant_name,
		header:, body:, ui:, save_directory:, method_contract:
	)
		super()
		# Have to call super() to initialize state_machine
		# if you don't, you get a symbol collision on '#draw'
		# because that is the method used to visualize the state machine.
		
		puts "setting up Live Coding environment"
		
		@window = window # for passing window to all callbacks
		
		
		@klass_name  = class_constant_name
		@save_file   = save_directory/'data.yml'
		@method_contract = method_contract
		
		
		@files = {
			:header => FilePair.new(header),
			:body   => FilePair.new(body),
			:ui     => FilePair.new(ui)
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
		
		
		
		
		
		# @wrapped_object.queue_input [ms, turn, sym, args]
		
		method_symbols = [
			:mouse_moved,
			:mouse_pressed, :mouse_dragged, :mouse_released,
			:mouse_scrolled,
			:key_pressed, :key_released
		]
		# --- create the acutal delegators
		method_symbols.each do |sym|
			meta_def sym do |*args|
				protect_runtime_errors do
					ms   = RubyOF::Utils.ofGetElapsedTimeMillis
					turn = self.turn_number
					
					if @wrapped_object.nil?
						# puts "null handler: #{sym}"
					else
						@wrapped_object.send sym, @window, *args
						# @user_interface.queue_input ms, turn, sym, args
					end
				end
			end
		end
		
		
		@history.save @wrapped_object
		
		
		# TODO: reallocate FBOs when the window size changes
		# TODO: see if changing FBO filtering makes text look less "thin"
		
		# Initialize FBOs for onion skin rendering during time travel mode
		settings = RubyOF::Fbo::Settings.new
		settings.width     = @window.width
		settings.height    = @window.height
		settings.minFilter = GL::GL_NEAREST
		settings.maxFilter = GL::GL_NEAREST
		# ^ just set the width and height to match that of the window,
		#   at least for now.
		
		@history_fbo = RubyOF::Fbo.new
		@history_fbo.allocate(settings)
		# TODO: create DSL for Fbo#allocate like with Font and Image
			
		@temp_fbo = RubyOF::Fbo.new
		@temp_fbo.allocate(settings)
	end
	
	# automatically save data to disk before exiting
	def on_exit
		puts "live coding history: #{@history.size} states"
	end
	
	def font_color=(color)
		@wrapped_object.font_color = color
	end
	
	
	
	
	state_machine :state, :initial => :running do
		state :running do
			def turn_number
				# @time_travel_i has not been set yet,
				# so get the value directly from the source
				@wrapped_object.update_counter.current_turn
			end
			
			# reload code as needed
			def update
				# puts "loader: update"
				
				
				# -- update files as necessary
				dynamic_load @files[:body]				
				
				# -- delegate update command
				sym = :update
				protect_runtime_errors do
					if @wrapped_object.nil?
						puts "null handler: #{sym}"
					else
						
						signal = @wrapped_object.send sym, @window
						
						@history.save @wrapped_object
						
						i = @wrapped_object.update_counter.current_turn
						puts "current turn: #{i}"
						@time_travel_i = i
						
						if signal == :end
							puts "saving history to file..."
							File.open(@window.data_dir/'history.log', "w") do |f|
								f.puts @history
							end
							
							self.finish()
						end
						
						# if you hit certain counter thresholds, you should pause for a bit, to slow execution down. that way, you can get the program to run in slow mo
						
						
						# # jump the execution back to an earlier update phase
						# # (this is basically a goto)
						# i = @wrapped_object.update_counter.current_turn
						# if i > 30
						# 	 @wrapped_object.update_counter.current_turn = 1
						# 	 @wrapped_object.regenerate_update_thread!
						# end
					end
				end
			end
			
			def draw
				sym = :draw
				protect_runtime_errors do
					if @wrapped_object.nil?
						puts "null handler: #{sym}"
					else
						@wrapped_object.send sym, @window
					end
				end
			end
		end
		
		# Don't generate new state, but render current state
		# and alllow time traveling. Can also just resume execution.
		state :paused do
			def turn_number
				@time_travel_i
			end
			
			def update
				# -- update files as necessary
				dynamic_load @files[:body]
			end
			
			def draw
				sym = :draw
				protect_runtime_errors do
					if @wrapped_object.nil?
						puts "null handler: #{sym}"
					else
						@wrapped_object.send sym, @window
					end
				end
			end
		end
		
		# Can't generate new state or resume until errors are fixed.
		# Can also use time traveling to help fix the errors.
		state :error do
			def turn_number
				@time_travel_i
			end
			
			# can't go forward until errors are fixed
			def update
				@window.show_text(CP::Vec2.new(352,100), "ERROR: See terminal for details. Step back to start time traveling.")
				
				# -- update files as necessary
				# need to try and load a new file,
				# as loading is the only way to escape this state
				dynamic_load @files[:body]
			end
			
			def draw
				# sym = :draw
				# protect_runtime_errors do
				# 	if @wrapped_object.nil?
				# 		puts "null handler: #{sym}"
				# 	else
				# 		@wrapped_object.send sym, @window
				# 	end
				# end
			end
		end
		
		# Like the "true ending" of a video game.
		# Execution has completed (update fiber has no more updates)
		# Time travel is allowed, but no more forward progess is possible.
		state :true_ending do
			def turn_number
				@time_travel_i
			end
			
			def update
				# @window.show_text(CP::Vec2.new(352,100), "Program completed!")
				
				# -- update files as necessary
				# need to try and load a new file,
				# as loading is the only way to escape this state
				dynamic_load @files[:body]
			end
			
			# normal drawing
			def draw
				sym = :draw
				protect_runtime_errors do
					if @wrapped_object.nil?
						puts "null handler: #{sym}"
					else
						@wrapped_object.send sym, @window
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
		# + true timeline      even if you roll all the way forward again,
		#                      you can't resume execution again
		#                      (execution complete, no more execution possbile)
		
		
		state :good_timeline do
			def turn_number
				@time_travel_i
			end
			
			def update
				# puts "============== good timeline ================"
				
				# populate state cache using serialized data
				if @history_cache.nil?
					@history_cache = Array.new
					
					@history.size.times do |i|
						state = @history[i]
						# p state
						@history_cache[i] = state
					end
					
					# p @history_cache
				end
				
				dynamic_load @files[:body]
			end
			
			# draw onion-skin visualization
			def draw
				# render the selected state
				# (it has been rendered before, so it should render now without errors)
				unless @history_cache.nil?
					# render the states
					# puts "history: #{@history_cache.size} - #{@history_cache.collect{|x| !x.nil?}.inspect}"
					
					# TODO: render to FBO once and then render that same state to the screen over and over again as long as @time_travel_i is unchanged
					# currently, framerate is down to ~30fps, because this render operation is expensive.
					
					# State 0 is not renderable, because that is before the first update runs. Without the first update, the first draw will fail. Just skip state 0. Later, when we attempt to compress history by diffs, state 0 may come in handy.
					render_onion_skin(
						@history_cache[1..(@time_travel_i-1)],  ONION_SKIN_STANDARD_COLOR,
						@history_cache[@time_travel_i],         ONION_SKIN_NOW_COLOR,
						@history_cache[(@time_travel_i+1)..-1], ONION_SKIN_STANDARD_COLOR
					)
					
					# @history_cache[@time_travel_i].draw @window
					
					# ^ currently the saved state is rendering some UI which shows what the current TurnCounter values are. This is going to have weird interactions with onion skinning. Should consider separating UI drawing from main entity drawing.
					# (or maybe onion-skinning the UI will be cool? idk)\					
				end
			end
		end
		
		# A failed timeline caused by fairly standard program errors.
		state :doomed_timeline do
			def turn_number
				@time_travel_i
			end
			
			def update
				# puts "============== true timeline ================"
				
				# populate state cache using serialized data
				if @history_cache.nil?
					@history_cache = Array.new
					
					@history.size.times do |i|
						state = @history[i]
						# p state
						@history_cache[i] = state
					end
					
					# p @history_cache
				end
				
				dynamic_load @files[:body]
			end
			
			# draw onion-skin visualization
			def draw
				# render the selected state
				# (it has been rendered before, so it should render now without errors)
				unless @history_cache.nil?
					# render the states
					# puts "history: #{@history_cache.size} - #{@history_cache.collect{|x| !x.nil?}.inspect}"
					
					# TODO: render to FBO once and then render that same state to the screen over and over again as long as @time_travel_i is unchanged
					# currently, framerate is down to ~30fps, because this render operation is expensive.
					
					# State 0 is not renderable, because that is before the first update runs. Without the first update, the first draw will fail. Just skip state 0. Later, when we attempt to compress history by diffs, state 0 may come in handy.
					render_onion_skin(
						@history_cache[1..(@time_travel_i-1)],  ONION_SKIN_STANDARD_COLOR,
						@history_cache[@time_travel_i],         ONION_SKIN_NOW_COLOR,
						@history_cache[(@time_travel_i+1)..-1], ONION_SKIN_STANDARD_COLOR
					)
					
					
					
					# @history_cache[@time_travel_i].draw @window
					
					# ^ currently the saved state is rendering some UI which shows what the current TurnCounter values are. This is going to have weird interactions with onion skinning. Should consider separating UI drawing from main entity drawing.
					# (or maybe onion-skinning the UI will be cool? idk)\					
				end
			end
		end
		
		# The timeline that preceeds the "true ending."
		# When you hit the "true_ending" state and proceed to time travel,
		# this is the timeline that gets used.
		state :true_timeline do
			def turn_number
				@time_travel_i
			end
			
			def update
				# puts "============== true timeline ================"
				
				# populate state cache using serialized data
				if @history_cache.nil?
					@history_cache = Array.new
					
					@history.size.times do |i|
						state = @history[i]
						# p state
						@history_cache[i] = state
					end
					
					# p @history_cache
				end
				
				dynamic_load @files[:body]
			end
			
			# draw onion-skin visualization
			def draw
				# render the selected state
				# (it has been rendered before, so it should render now without errors)
				unless @history_cache.nil?
					# render the states
					# puts "history: #{@history_cache.size} - #{@history_cache.collect{|x| !x.nil?}.inspect}"
					
					# TODO: render to FBO once and then render that same state to the screen over and over again as long as @time_travel_i is unchanged
					# currently, framerate is down to ~30fps, because this render operation is expensive.
					
					# State 0 is not renderable, because that is before the first update runs. Without the first update, the first draw will fail. Just skip state 0. Later, when we attempt to compress history by diffs, state 0 may come in handy.
					render_onion_skin(
						@history_cache[1..(@time_travel_i-1)],  ONION_SKIN_STANDARD_COLOR,
						@history_cache[@time_travel_i],         ONION_SKIN_NOW_COLOR,
						@history_cache[(@time_travel_i+1)..-1], ONION_SKIN_STANDARD_COLOR
					)
					
					
					
					# @history_cache[@time_travel_i].draw @window
					
					# ^ currently the saved state is rendering some UI which shows what the current TurnCounter values are. This is going to have weird interactions with onion skinning. Should consider separating UI drawing from main entity drawing.
					# (or maybe onion-skinning the UI will be cool? idk)\					
				end
			end
		end
		
		
		
		
		# once you are in this state, the load has succeeded.
		# at this point, you attempt to generate a forecast.
		# if the forecast fails -> :forecasting_error (a failed timeline variant)
		# 
		# You transition out of :forecasting by stepping forward into new future.
		state :forecasting do
			def turn_number
				@time_travel_i
			end
			
			# update everything all at once
			# (maybe do that on the transition to this state?)
			def update
				@forecast_fiber ||= Fiber.new do
					puts "forecasting..."
					
					# update the state
					protect_runtime_errors do
						# TODO: figure out if I can remove the nil check by enforcing some paths in the state system. can I be sure that by this point, @wrapped_object will be non-nil?
						if @wrapped_object.nil?
							puts "null handler: forecasting"
						else
							@forcasted_the_end = false
							@forecasting_lock = true
							
							# forecasting is a bit different from normal time traveling.
							# In normal time traveling, you just need to draw the states,
							# but in forecasting, you want to run the code again.
							
							# Therefore...
							
							# these are the states you want to draw
							target_range = ((@time_travel_i+1)..(@history.length-1))
							
							# but you have to re-simulate them first,
							# so you need the states prior to those
							grab_range = ((target_range.min-1)..(target_range.max-1))
							
							# now we can grab states, update them, and then draw them
							grab_range.each do |i|
								# -- get the state
								state = @history[i]
								
								# -- update state
								sym = :update
								signal = state.send sym, @window
								
								# -- save
								@history.save state
								
								# @time_travel_i = i
								@forecast_range = ((target_range.min)..(i+1))
								# ^ shows range of history that was overridden by forecasting
								
								@history_cache[@forecast_range.max] = state
								# ^ can store this state object in cache, because next frame I'll pull a new object from @history
								# (In fact, the object I pull out will be a copy of this one)
								
								# if there's an error, we will transition to "forecasting_error"
									# (automatically caught by protect_runtime_errors block)
									# (automatically transition due to state machine)
								
								
								
								
								# otherwise, visualize the correct forecasting path by transitioning to a different time-traveling state
								
								if signal == :end
									@forcasted_the_end = true
									
									# # if the last state generated results in the update fiber running to completion, then the found timeline is actually the "true timeline". In that case, call this method instead:
									# self.forecast_found_true_timeline()
									# break # may be stopping short of the previous timeline's end
									# # when breaking out into the true timeline, you can resize the history cache if the true ending occurs before the current end of the cache.
									# 	# => callback: on_forecast_to_true_timeline
									
								end
							end
							
							@forecasting_lock = false
						end
					end
					
					# When time traveling ends in the true timeline, execution temporarily returns to the :running state, executes a NO-OP and then proceeds to the "true ending."
					# May not have to have separate forecast_found_good_timeline() and forecast_found_true_timeline() functions. It may be sufficient to return to the paused / running state.
					
					# alternatively: may be able to use the same timeline called state, and then branch based on a callback defined elsewhere?
					# nah, that sounds bad.
				end
				
				@forecast_fiber.resume while @forecast_fiber&.alive?
				
				dynamic_load @files[:body]
			end
			
			# draw onion-skin visualization
			def draw
				# render the selected state
				# (it has been rendered before, so it should render now without errors)
				unless @forecast_range.nil?
					# render the states
					# puts "history: #{@history_cache.size} - #{@history_cache.collect{|x| !x.nil?}.inspect}"
					
					# TODO: render to FBO once and then render that same state to the screen over and over again as long as @time_travel_i is unchanged
					# currently, framerate is down to ~30fps, because this render operation is expensive.
					
					# State 0 is not renderable, because that is before the first update runs. Without the first update, the first draw will fail. Just skip state 0. Later, when we attempt to compress history by diffs, state 0 may come in handy.
					render_onion_skin(
						@history_cache[1..(@time_travel_i-1)],  ONION_SKIN_STANDARD_COLOR,
						@history_cache[@time_travel_i],         ONION_SKIN_NOW_COLOR,
						@history_cache[@forecast_range],        ONION_SKIN_FORECAST_COLOR
					)
					
					
					
					# @history_cache[@time_travel_i].draw @window
					
					# ^ currently the saved state is rendering some UI which shows what the current TurnCounter values are. This is going to have weird interactions with onion skinning. Should consider separating UI drawing from main entity drawing.
					# (or maybe onion-skinning the UI will be cool? idk)\					
				end
			end
		end
		
		
		# A failed timeline caused by the time ripples from forecasting.
		# 
		# Can only resume after successful forecasting
		# (very bad - time record has become corrupted)
		state :forecasting_error do
			def turn_number
				@time_travel_i
			end
			
			# (code adapted from :error)
			def update
				# -- update files as necessary
				# need to try and load a new file,
				# as loading is the only way to escape this state
				dynamic_load @files[:body]
			end
			
			# draw onion-skin visualization
			# (code copied from :true_timeline)
			def draw
				# render the selected state
				# (it has been rendered before, so it should render now without errors)
				unless @history_cache.nil?
					# render the states
					# puts "history: #{@history_cache.size} - #{@history_cache.collect{|x| !x.nil?}.inspect}"
					
					# TODO: render to FBO once and then render that same state to the screen over and over again as long as @time_travel_i is unchanged
					# currently, framerate is down to ~30fps, because this render operation is expensive.
					
					# State 0 is not renderable, because that is before the first update runs. Without the first update, the first draw will fail. Just skip state 0. Later, when we attempt to compress history by diffs, state 0 may come in handy.
					render_onion_skin(
						@history_cache[1..(@time_travel_i-1)], ONION_SKIN_STANDARD_COLOR,
						@history_cache[@time_travel_i],        ONION_SKIN_NOW_COLOR,
						@history_cache[@forecast_range],       ONION_SKIN_ERROR_COLOR
					)
					
					
					# @history_cache[@time_travel_i].draw @window
					
					# ^ currently the saved state is rendering some UI which shows what the current TurnCounter values are. This is going to have weird interactions with onion skinning. Should consider separating UI drawing from main entity drawing.
					# (or maybe onion-skinning the UI will be cool? idk)\					
				end
			end
		end
		
		
		
		
		# 
		# process errors
		# 
		
		event :runtime_error do
			# regular runtime errors
			transition :running => :error
			
			# tried to forecast, but hit an exception while generating new state
			transition :forecasting => :forecasting_error
		end
		
		event :load_error do
			# tried to reload under normal execution conditions, but failed
			transition :running => :error
			transition :paused => :error
			transition :error => :error
			transition :true_ending => :error
			
			# tried to forecast, but there was a load error
			transition :forecasting_error => :forecasting_error
			
			transition :good_timeline => :forecasting_error
			transition :doomed_timeline => :forecasting_error
			transition :forecasting_error => :forecasting_error
			transition :true_timeline => :forecasting_error
		end
		
		event :successful_reload do
			transition :running => :running
			transition :paused => :paused
			transition :error => :running
			transition :true_ending => :running
			
			transition :forecasting => :forecasting
			
			transition :good_timeline => :forecasting
			transition :doomed_timeline => :forecasting
			transition :forecasting_error => :forecasting
			transition :true_timeline => :forecasting
		end
		
		after_transition :on => :successful_reload, :do => :on_reload
		after_transition :to => :forecasting_error, :do => :on_reload
		
		# after_transition :error => :running do
		# 	# puts "error resolved!"
		# end
		
		
		
		# 
		# standard transitions
		# 
		
		# temporarily pause execution
		# (really want to just pause the updating, but continue to draw)
		event :pause do
			transition :running => :paused
		end
		
		# resume execution after pausing
		event :resume do
			transition :paused => :running
			transition :running => :running
		end
		
		# finsh execution
		event :finish do
			transition :running => :true_ending
		end
		
		
		# You can "time travel," scrubbing through past states.
		event :begin_time_travel do
			transition :paused => :good_timeline
			transition :error => :doomed_timeline
			transition :true_ending => :true_timeline
			transition :forecasting_error => :forecasting_error
		end
		
		after_transition :on => :begin_time_travel, :do => :on_time_travel_begin
		
		
		# Stop time traveling, and return to a stable point in time.
		event :end_time_travel do
			transition :good_timeline => :paused, :if => :end_of_timeline?
			transition :doomed_timeline => :error, :if => :end_of_timeline?
			transition :true_timeline => :true_ending, :if => :end_of_timeline?
			# The only way to escape a :forecasting_error is to forecast again.
			# (you must stabilize the time rift before time traveling again)
		end
		
		after_transition :on => :end_time_travel, :do => :on_time_travel_end
		
		
		
		# After one or more forecasts, you have found a timeline worth exploring.
		# Stepping into the time rift, the timelines collapse,
		# and only the way to the new future remains.
		# 
		# Will take you to the good timeline, which may end up
		# actually being a true timeline.
		event :end_forecasting do
			transition :forecasting =>  :good_timeline
		end
		
		after_transition :on => :end_forecasting, :do => :on_forecast_end
		
		
		
		
		
		after_transition :to => :error, :do => :on_error
		# block callbacks will execute in the context of StateMachine,
		# where as method callbacks will execute in the context of Loader
		
		
		after_transition :to => :forecasting_error, :do => :on_forecasting_error
	end
	
	
	# time travel interface
	# Step backwards one frame in history
	def step_back
		puts "step back"
		
		# @time_travel_i == @history.length-1
		# puts "turn: #{@wrapped_object.update_counter.current_turn}" 
		# puts "target: #{@history.length-1}"
		
		# @forecasting_lock   # <-- if true, currently calculating forecast
		
		
		if self.state_name == :forecasting
			return if @forecasting_lock
			
			# can't travel to t=0 ; the initial state is not renderable
			if @time_travel_i > 1
				@time_travel_i -= 1
			end
		elsif self.state_name == :forecasting_error
			# can't travel to t=0 ; the initial state is not renderable
			if @time_travel_i > 1
				@time_travel_i -= 1
			end
		elsif self.state.include? "timeline"
			# (already in time traveling mode)
			# step backwards in time
			
			# can't travel to t=0 ; the initial state is not renderable
			if @time_travel_i > 1
				@time_travel_i -= 1
			end
		else
			# (not currently time traveling)
			# start time traveling
			return if self.state_name == :running
				# + :running is for actively executing code. pause execution first.
			
			self.begin_time_travel()
			puts "time traveling to: #{self.state}"
		end
	end
	
	# time travel interface
	# Step forwards one frame in history
	def step_forward
		puts @time_travel_i
		
		if self.state_name == :forecasting
			return if @forecasting_lock
			
			if @time_travel_i < @forecast_range.min-1
				# before the forecasted region, you can step forward
				@time_travel_i += 1
			elsif @time_travel_i == @forecast_range.min-1
				# if you step forward into the forecasted region,
				# you commit to a "good timeline"
				@time_travel_i += 1
				self.end_forecasting()
				puts "collapsing timelines. moving to: #{self.state}"
			else
				raise "ERROR: unknown time-traveling inconsistency while forecasting"
			end
			
		elsif self.state_name == :forecasting_error
			# Past a certain timepoint, time has been corrupted.
			# This point will be earlier than the normal end of the timeline.
			# You are not allowed to step into this corrupted time rift.
			# 
			# The only way to leave the :forecasting_error state
			# is by performing a successful forecast.
			
			if @time_travel_i < @forecast_range.min-1
				# the last state you can reach, is the one right before the time rift
				@time_travel_i += 1
				# (there is no good state in the rift to step into)
			end
		elsif self.state.include? "timeline"
			# (must be in time traveling mode, excluding :forecasting)
			# (:forecasting is handled in a separate branch below)
			puts "step forward"
			
			# Use normal timeline boundary, for normal actions.
			
			if end_of_timeline?
				# TODO: try removing the pause state
				
				# if paused -> time travel : resume execution
				# if error -> time travel : return to :error state
				# if hit true ending -> time travel : return to true end
				self.end_time_travel()
				puts "time traveling to stable timepoint: #{self.state}"
			else
				
				if @time_travel_i < @history.length-1
					@time_travel_i += 1
				end
				
			end
		end
	end
	
	def end_of_timeline?
		# TODO: figure out how to detect this properly
		# maybe compare the size of history to the turn counter?
		
		return (@time_travel_i == @history.length-1)
	end
	
	
	
	private
	
	
	
	def on_time_travel_begin
		# TODO: optimize history cache population and usage.
		# + don't try to fill cache all in one frame
		# + don't throw out the entire cache if some items are still good
    #   (cache invalidation is hard)
    # + optimize onion skin rendering
		# @history_cache.each do |state|
		# 	world_space  = state.instance_variable_get "@world_space"
		# 	screen_space = state.instance_variable_get "@screen_space"
			
		# 	[world_space, screen_space].each do |space|
		# 		space.clear
		# 	end
		# end
		@history_cache = nil
			# end
			@history_cache.each do |state|
				world_space  = state.instance_variable_get "@world_space"
				screen_space = state.instance_variable_get "@screen_space"
				
				
				 = world_space.entities + screen_space.entities
				[world_space, screen_space].each do |space|
					space.clear
					
					require 'pry'
					binding.pry
					
					# space.update(1/60.0)
					
					# ^ it seems like this may be sufficient to prevent the segfault? it's possible that there's some state that's supposed to get initialized on #update() that never gets initialized for states in history. That would make things complicated, to say the least.
					
					# TODO: Space#update has two parts. Try calling just CP::Space#step() or just updating the entities. Need to figure out which part is necessary to fix the error.
					
					# Space#update is supposed to take 0 arguments. If you actually pass 0 args -> segfault. If you pass this one arg -> no segfault. What is going on????
						# when you pass 1 arg, you get a runtime error, but the system is blocking the program from crashing on that error, and the console is currently flodded with other messages, so you end up not seeing the error.
					
					
					# space.instance_variable_get("@cp_space").step(1/60.0)
					# ^ calling just CP::Space#step does not fix the issue. still segfault
					
					# space.instance_variable_get("@entities").each do |entity|
					# 	entity.update
					# end
					
				end
			end
		# ^ this is a hacky way to try and take control of when resources get released. I'm hoping this will fix the segfault. If it does, that means I understand the source of the error. From there, I need to actually implement a sane solution.
		# YES. this does fix the problem.
		
		# well, it doesn't actually work.
		# it just causes an execption to be thrown that prevents the line below to be called, thus avoiding the issue entirely...
		
		@history_cache = nil
		
		
		# i = @wrapped_object.update_counter.current_turn
		# puts "current turn: #{i}"
		# @time_travel_i = i
		# ^ I forgot why I don't set the i here, but there must have been a reason. Need to figure that out, and document it.
	end
	
	def on_time_travel_end
		
	end
	
	
	
	
	def on_forecast_end
		on_reload()
		
		# resize the history cache
		@history_cache = @history_cache.slice(0..(@forecast_range.max))
			# Array#slice    return the portion in the range
			
			# Array#slice!   return the portion in the range
			#                and modify the array to delete that portion
		
		
		
		# final state in history cache is the new wrapped object
		@wrapped_object = @history_cache.last
		
		# reset @forecast_range variable used by :forecasting
		@forecast_range = nil
	end
	
	
	def on_forecasting_error
		puts "FORECASTING ERROR on turn #{@forecast_range.max} (message below)"
	end
	
	
	
	def on_error
		puts "------> error detected"
		puts @klass_name
		puts self.class
	end
	
	def on_reload
		unless @wrapped_object.nil?
			@wrapped_object.regenerate_update_thread!
			@wrapped_object.regenerate_draw_thread!
		end
		
		@forecast_fiber = nil
	end
	
	# NOTE: under this architecture, you can't dynamically change initialization or serialization code - you would have to restart the program if that sort of change is made
	# ^ is this still true?
	
	
	
	
	
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
						@wrapped_object.send sym, @window, *args
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
			# switch states first, in case extra messages need to be printed to contexualize the actual exception
			self.runtime_error()
			
			
			# keep execption from halting program,
			# but still output the exception's information.
			print_wrapped_error(e)
			
			
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
			# NOTE: file timestamps only have 1 sec resolution, so there may be a slight delay when attempting to reload more than once per second.
			if file.changed?
				file.update_time
				# NOTE: Timestamps updated whenever load is *attempted*
					# This is actually what you want.
					# If you don't do it this way, then when there is a load error,
					# the system will try and fail to reload the file every tick
					# of the main loop.
					# This will generate a lot of useless noise in the log.
					# However, once the file is updated, you expect the system to
					# attempt a reload at least once.
				
				puts "live loading #{file}"
				load file.to_s
				self.successful_reload()
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
			
			puts "FAILURE TO LOAD: #{file}"
			
			print_wrapped_error(e)
			
			self.runtime_error()
		ensure
			
		end
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
	
	
	
	# (I can't do this right now. This would involve version control.)
	def revert_code()
		
	end
	
	
	
	
	
	
	# Render mulitple time points to the same @window, visualizing time as space.
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
	def render_onion_skin(before_states, before_color, current_state, current_color, after_states, after_color)
		# @history_fbo   used for final render
		# 
		# @temp_fbo      accumulation buffer. render each state to this
		#                then render this into the final FBO
		@history_fbo.begin()
			# need to clear the buffer,
			# or you get whatever garbage is in there
			ofClear(255,255,255,0)
		@history_fbo.end()
		
		
		# -- render before states
			# composite this layer into the onion skin
			@history_fbo.begin()
		before_states.each do |state|
			# p state
			
			# render one layer
			render_onion_skin_layer(@temp_fbo) do
				state.draw @window
			end
			
				
				ofSetColor(before_color)
				@temp_fbo.draw(0,0)
				
		end
			@history_fbo.end()
		
		
			# composite this layer into the onion skin
			@history_fbo.begin()
		# -- render future states
		after_states.each do |state|
			# p state
			
			# render one layer
			render_onion_skin_layer(@temp_fbo) do
				state.draw @window
			end
			
				
				ofSetColor(after_color)
				@temp_fbo.draw(0,0)
				
		end
			@history_fbo.end()
		
		
		# -- render current state
		# render one layer
		render_onion_skin_layer(@temp_fbo) do
			current_state.draw @window
		end
		
		# composite this layer into the onion skin
		@history_fbo.begin()
			ofPushStyle()
			
				ofSetColor(current_color)
				@temp_fbo.draw(0,0)
				
			ofPopStyle()
		@history_fbo.end()
		
		
		
		# render the final onion skin visualization to the screen
		@history_fbo.draw(0,0)
	end
	
	def render_onion_skin_layer(fbo) # &block
		# render state to a single "layer" using an FBO
			fbo.begin()
				# need to clear the buffer,
				# or you get whatever garbage is in there
				ofClear(255,255,255,0)
				
				# render some things into the fbo here
				# (rendering relative to the orign of the FBO, which moves)
				ofPushStyle()
				ofPushMatrix()
					
					yield
					
				ofPopMatrix()
				ofPopStyle()
			fbo.end()
	end
	
	
	
	
	def render_standard_world
		
	end
	
	def render_ui
		
	end
	
	
	
end

end
