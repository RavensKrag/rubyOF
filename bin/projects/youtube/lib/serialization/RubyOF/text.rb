class Text < Entity
	# def to_yaml_type
	# 	"!ruby/object:#{self.class}"
	# end

	# def encode_with(coder)
	# 	coder.represent_map to_yaml_type, { 
	# 		'r' => self.r,
	# 		'g' => self.g,
	# 		'b' => self.b,
	# 		'a' => self.a,
	# 	}
	# end
	
	def init_with(coder)
		# p coder
		
		initialize(coder.map['font'], coder.map['string'])
		
		# regenerate the text mesh, as that can not be saved
		@text_mesh = nil
		self.update
	end
end
