module RubyOF

class Color
	include Freezable
	
	def to_s
		"Color (rgba): #{self.r}, #{self.g}, #{self.b}, #{self.a}"
	end
end

end
