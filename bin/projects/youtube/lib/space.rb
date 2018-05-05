class Space
	def initialize
		@cp_space = CP::Space.new
		@entities = Array.new
	end
	
	
	# TODO: add entity to space as well
	def add(entity)
		@entities << entity
	end
	
	def delete(entity)
		@entities.delete entity
	end
	
	def entities
		# return frozen shallow copy
		@entities.clone.freeze
	end
	
	
	
	def update
		@entities.each do |entity|
			entity.update
		end
	end
	
	def draw
		# TODO: only draw what is visible to some camera
		
		# Render queue should sort by shader, then texture, then z depth [2]
		# (I may want to sort by z first, just because that feels more natural? Sorting by z last may occasionally cause errors. If you sort by z first, the user is always in control.)
		# 
		# [1]  https://www.gamedev.net/forums/topic/643277-game-engine-batch-rendering-advice/
		# [2]  http://lspiroengine.com/?p=96
		
		@entities.group_by{ |e| e.texture }
		.each do |texture, same_texture|
			texture.bind
			
			same_texture.each do |entity|
				entity.draw
			end
			
			texture.unbind
		end
	end
end 


# + Space can add Entity objects

# + Space can delete Entity objects

# + Space has an attribute 'entities' which just lists all entities stored in the space, but you don't want to let people add entities through that interface
# 		(make sure you #freeze the Array, but *not* a deep freeze)
