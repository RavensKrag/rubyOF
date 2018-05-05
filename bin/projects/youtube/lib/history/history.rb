class History
	NULL_STATE = []
	
	attr_reader :messages, :position
	
	def initialize(space)
		@space = space
		
		@position = 0 # active index the History data structure
		@states  = Array.new
		@messages = Array.new
		
		# commit initial state
		# entities = @space.entities.collect{ |x| x }
		# state = entities.collect{ |x|  x.serialize}
		commit NULL_STATE, "New document"
		
		
		commit NULL_STATE, "hello"
		
		
		commit NULL_STATE, "world"
		commit NULL_STATE, "test"
		commit NULL_STATE, "foo"
	end
	
	# Move to position i in the history stack,
	# undoing / redoing actions as needed.
	def goto(i)
		puts "goto history index #{i}"
		@position = i
		restore @states[@position]
		
		return @position
	end
	
	def undo
		if @position > 0
			@position -= 1
			restore @states[@position]
		end
		
		return @position
	end
	
	def redo
		max_pos = @states.length-1
		if @position < max_pos
			# @position needs to still be a valid index
			# after taking 1 step forward
			@position += 1
			restore @states[@position]
		end
		
		return @position
	end
	
	def squash
		return @position
	end
	
	
	
	
	# add new state to history
	def commit(state, message)
		if @states.empty? or @position == @states.size-1
			# At end of history, or no items in history yet.
			# Don't need to wipe any history - just add new stuff.
			@position += 1
			@states   << state
			@messages << message
		else
			# Not at the end.
			# Need to wipe future history from collection, before committing
			
			# delete all entries in range
			range = (@position+1)..-1
			@states.slice!(range)
			@messages.slice!(range)
			
			@position = @states.size-1
			
			commit(state, message) # recursive call (goes to first case)
		end
	end
	
	
	
	
	private
	
	
	
	
	# --
	# roll back
	# (reinit existing data where possible, otherwise create data)
	# -----
	# state => [Serialized] (it's just an array, nothing fancy)
	# 
	# serialized.type => String : name of entity Class
	# serialized.id   => unique identifier (string, int, whatever, I don't care)
	# serialized.data => Array : data needed to reconstruct the entity
	def restore(state)
		# parse serialized data
		ids = state.collect{ |s| s.id  }
		
		# what entities are currently active?
		entities = @space.entities.select{ |entity| ids.include? entity.id }
		entity_ids = entities.collect{ |x| x.id }
		
		# what entities can we reinit *vs* what do we need to create anew?
		reinit_list, init_list = state.partition{ |s| entity_ids.include? s.id }
		
		
		# reinit existing entities
		reinit_types, reinit_ids, reinit_serializations = 
			reinit_list.collect{ |s|
				[s.type, s.id, s.data] # convert to Serialized into triple
			}.transpose # turn list of triples into 3 lists
		
		unless reinit_serializations.nil?
			entities.select{ |e|
				reinit_ids.include? e.id
			}.zip(reinit_serializations).each do |entity, data|
				entity.deserialize(data)
			end
		end
		
		
		# init new entities
		init_list.collect{ |s|
			# klass = Entity.get_type(s.type) # maybe use Kernel.const_get instead?
			klass = Kernel.const_get(s.type)
			entity = klass.new(s.id)
			entity.deserialize(s.data)
		}.each do |entity|
			@space.add entity
		end
		
		
		# delete entities that don't exist in the state we're jumping to
			# + find what exists in current, but not in target
			# + delete those items from the space
		target_ids = ids
		current_ids = @space.entities.collect{ |e| e.id }
		
		delete_ids = (current_ids - target_ids)
		
		@space.entities
		.collect{ |entity|
			delete_ids.include? entity # find the ones we need
		}.each do |entity|
			@space.delete entity # remove them from simulation space
		end
	end
end

