module CP


class Vec2
	def to_yaml_type
		"!ruby/object:#{self.class}"
	end

	def encode_with(coder)
		coder.represent_map to_yaml_type, { 'x' => self.x, 'y' => self.y }
	end

	def init_with(coder)
		x = coder.map['x']
		y = coder.map['y']
		initialize(x,y)
	end
end



end
