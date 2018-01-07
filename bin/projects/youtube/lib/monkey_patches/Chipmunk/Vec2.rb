module CP
	class Vec2
		class << self
			# Return the angle between two vectors
			def angle_between(v1, v2)
				# normalization of zero vectors results in NaN, which is really bad
				v1 = v1.normalize unless v1.zero?
				v2 = v2.normalize unless v2.zero?
				
				cos = v1.dot v2
				
				theta = Math::acos(cos)
				
				return theta
			end
			
			def midpoint(v1, v2)
				return Vec2.new((v1.x + v2.x)/2, (v1.y + v2.y)/2)
			end
		end
		
		def zero?
			return self.x == 0 && self.y == 0
		end
		
		def clone
			return CP::Vec2.new(self.x, self.y)
		end
	end
end