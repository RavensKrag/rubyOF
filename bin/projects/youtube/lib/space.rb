class Space
	def initialize
		@cp_space = CP::Space.new
		@entities = Array.new
	end
	
	
	
	def add(entity)
		@entities << entity
	end
	
	def delete(entity)
		@entities.delete entity
	end
	
	def entities
		@entities.freeze
	end
end 


# + Space can add Entity objects

# + Space can delete Entity objects

# + Space has an attribute 'entities' which just lists all entities stored in the space, but you don't want to let people add entities through that interface
# 		(make sure you #freeze the Array, but *not* a deep freeze)
