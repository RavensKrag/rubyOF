class Space
	def to_yaml_type
		"!ruby/object:#{self.class}"
	end
	
	def encode_with(coder)
		data = {
			'entities' => @entities
		}
		
		coder.represent_map to_yaml_type, data
	end
	
	def init_with(coder)
		# p coder.map
		initialize()
		
		# p coder.map['entities']
		
		coder.map['entities'].each do |e|
			self.add e
		end
	end
end
