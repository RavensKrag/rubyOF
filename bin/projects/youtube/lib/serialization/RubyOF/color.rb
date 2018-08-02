module RubyOF


class Color
	def to_yaml_type
		"!ruby/object:#{self.class}"
	end

	def encode_with(coder)
		coder.represent_map to_yaml_type, { 
			'r' => self.r,
			'g' => self.g,
			'b' => self.b,
			'a' => self.a,
		}
	end

	def init_with(coder)
		# c = RubyOF::Color.new
		# c.r, c.g, c.b, c.a = [0, 0, 0, 255]
		
		initialize()
		
		self.r = coder.map['r']
		self.g = coder.map['g']
		self.b = coder.map['b']
		self.a = coder.map['a']
	end
end



end

