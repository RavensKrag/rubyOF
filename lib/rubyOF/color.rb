module RubyOF

class Color
	include Freezable
	
	def to_s
		"Color (rgba): #{self.r}, #{self.g}, #{self.b}, #{self.a}"
	end
	
	def ==(other)
		[:r, :g, :b, :a].all? do |channel|
			self.send(channel) == other.send(channel)
		end
	end
end

end
