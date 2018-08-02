module RubyOF


class TrueTypeFont
	def to_yaml_type
		"!ruby/object:#{self.class}"
	end

	# def encode_with(coder)
	# 	coder.represent_map to_yaml_type, { 'x' => self.x, 'y' => self.y }
	# end

	def init_with(coder)
		initialize()
		self.load coder.map['settings']
	end
end

class TrueTypeFontSettings
	def to_yaml_type
		"!ruby/object:#{self.class}"
	end

	def encode_with(coder)
		coder.represent_map to_yaml_type, {
			'font_name' => self.font_name,
			'font_size' => self.font_size,
			'antialiased?' => self.antialiased?,
			'ranges' => @ranges,
			'alphabets' => @alphabets
		}
	end

	def init_with(coder)
		initialize(coder.map['font_name'], coder.map['font_size'])
		
		self.antialiased = coder.map['antialiased?']
		
		# loney operator: load ranges and alphabets if they are non-nil
		
		coder.map['ranges']&.each do |range|
			self.add_unicode_range range
		end
		
		coder.map['alphabets']&.each do |alphabet|
			self.add_alphabet alphabet
		end
	end
end



end
