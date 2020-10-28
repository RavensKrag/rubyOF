class Space
	def initialize
		@cp_space = CP::Space.new
		@entities = Array.new
	end
	
	
	# TODO: add entity to space as well
	def add(entity)
		# TODO: set entity ID when adding to Space
		# (without a proper unique ID, serialization will not work. without serialization, we can't roll back history.)
		@entities << entity
		
		
		@cp_space.add_shape(entity.shape)
		@cp_space.add_body(entity.body)
	end
	
	def delete(entity)
		@entities.delete entity
		
		@cp_space.remove_shape(entity.shape)
		@cp_space.remove_body(entity.body)
	end
	
	def clear
		@entities.each do |entity|
			@cp_space.remove_shape(entity.shape)
			@cp_space.remove_body(entity.body)
		end
		@entities.clear
	end
	
	def entities
		# return frozen shallow copy
		@entities.clone.freeze
	end
	
	
	
	def update
		@cp_space.step(1/60.0)
		
		@entities.each do |entity|
			entity.update
		end
	end
	
	
	
	def bb_query(bb, layers=CP::ALL_LAYERS, group=CP::NO_GROUP, &block)
		# block params: |object_in_space|
		@cp_space.bb_query(bb, layers, group) do |shape|
			block.call(shape.object)
		end
	end
end
