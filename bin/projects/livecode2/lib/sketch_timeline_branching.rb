class Controller
	def initialize(code_history, space_history, input_history)
		@timelines = Array.new
		@timeline_i = 0
    
		@timelines << Timeline.new(code_history, space_history, input_history)
    
    
    
    # using evented callbacks, all state checking can be handled in Controller
    # ---
    # coupling is minimized:
    # only couple Controller to specific instances of LiveCode where that functionality is necessary, rather than linking Controller and LiveCode at the class level.
    code_history.define_reload_callback do
      branch() if current_timeline.state == :time_traveling
    end
	end
  
  def current_timeline
    @timelines[@timeline_i]
  end
	
	def update
		
	end
	
	def branch
		# create new timeline
		new_timeline = current_timeline.dup
		
		# make new timeline distinct from the main one you just branched
		new_timeline.reset
		new_timeline.update
		
		# commit new timeline
		@timelines << new_timeline
		@timeline_i = @timelines.length-1
	end
end

class Timeline
	def initialize(code_history, space_history, input_history)
		@code_history = code_history
		@space_history = space_history
		@input_history = input_history
	end
	
	def update
		[
      @code_history,
      @space_history,
      @input_history
    ].each do |history|
      history.update
    end
	end
	
	def reset
    [
      @code_history,
      @space_history,
      @input_history
    ].each do |history|
      history.reset
    end
  end
end

class History
	def initialize
		
	end
	
	def update
		
	end
end

class LiveLoader
	def initialize
		@reload_callback = nil
	end
	
	def update
		
	end
	
	def on_reload
    @inner.on_reload
    @reload_callback.call() unless @reload_callback.nil?
    # ^ need to figure out how to set this back up after serialization
	end
  
  
  def define_reload_callback(&block)
    @reload_callback = block
  end
end
