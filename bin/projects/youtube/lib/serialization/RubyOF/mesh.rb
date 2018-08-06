module RubyOF


class Mesh
	def to_yaml_type
		"!ruby/object:#{self.class}"
	end

	def encode_with(coder)
		coder.represent_scalar to_yaml_type, ''
	end

	# def init_with(coder)
	# 	initialize()
	# end
end



end

