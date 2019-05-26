class History
	attr_reader :inner
	
	def initialize(inner)
		@inner = inner # object whose history is being saved (active object)
		
		@data  = [] # serialized data (holds all data)
      @cache = [] # live objects (often only a subset of @data)
	end
	
	
	
	# update the inner item
	def update
		@inner.update
	end
	
	# save new item to the head of the history queue
	def save
		
	end
	
	
	def step_forward
		
	end
	
	def step_backward
		
	end
	
	
	def each_in_cache
		
	end
end
