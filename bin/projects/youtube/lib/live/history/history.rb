 
class ExecutionHistory
	extend Forwardable
	
	def initialize
		@history = Array.new
	end
	
	def to_s
		@history.each_with_index.collect{ |state, i|
			"#{i.to_s.rjust(5, '0')}  =>  " + state 
		}.join("\n")
	end
	
	def_delegators :@history, :size, :length
	
	
	def save(obj)
		# NOTE: Don't hang on to obj, and don't hang on to obj.save
		#       References are being passed around, not deep copies.
		
		if @history.size < 10 # temp condition so history doesn't grow too large
			state = obj.save.to_yaml
			@history << state
		end
		
		
		# temp code to print the state to the terminal
		if @history.size == 10
			puts self
			@history << nil
		end
	end
	
	# move back in time
	def undo
		
	end
	
	# step forward in time, replaying old state
	def redo
		
	end
	
	# "butterfly effect" mode where new code
	# will be applied on old data and input
	# to predict interesting future states.
	def forecast
		
	end
end
