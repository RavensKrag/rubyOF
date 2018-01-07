require 'yaml'

module CP
	class BB
		# init order: [l,b,r,t]
		
		def draw(color, z=0)
			l,b,r,t = [self.l, self.b, self.r, self.t].collect{ |i|  i.round }
			$window.draw_quad	l, t, color,
								r, t, color,
								r, b, color,
								l, b, color, z
		end
		
		
		# TODO: fully finish the BB equality implementation (need to implement other methods too)
		def ==(other)
			return false unless other.is_a? self.class
			
			a = [other.l, other.b, other.r, other.t]
			b = [self.l, self.b, self.r, self.t]
			a.zip(b).all?{|a,b| a == b}
		end
		
		# Make sure that r < l and b < t, as expected
		# call this as a separate method rather than altering constructor
		# because it may be useful on occasion to have the bb twisted inside-out
		def reformat
			if self.r < self.l
				# swap r and l
				swap = self.r
				self.r = self.l
				self.l = swap
			end
			if self.t < self.b
				# swap top and bottom
				swap = self.t
				self.t = self.b
				self.b = swap
			end
		end
		
		def position
			CP::Vec2.new(self.l, self.b)
		end
		
		def center
			CP::Vec2.new(self.l+width/2, self.b+height/2)
		end
		
		def corners(start=:top_left, rotation=:clockwise)
			# CW from top left
			
			# pattern
			# 11	top left
			# 10	top right
			# 00	bottom right
			# 01	bottom left
			
			# 1,1,0,0  truth value
			# 1,2,3,4  index
			
			top, left =	case start
							when :top_left
								[1, 2]
							when :top_right
								[2, 3]
							when :bottom_right
								[3, 4]
							when :bottom_left
								[4, 1]
						end
			
			
			
			output = Array.new(4)
			output.each_index do |i|
				x =	if left <= 2
						self.l
					else
						self.r
					end
				
				y =	if top <= 2
						self.t
					else
						self.b
					end
				
				output[i] = CP::Vec2.new(x,y)
				
				
				x += 1
				x = 1 if x > 4
				
				y += 1
				y = 1 if y > 4
			end
			
			
			if rotation == :clockwise || rotation == :cw
				# should already by cw
			elsif rotation == :clockwise || rotation == :anticlockwise || rotation == :ccw
				# reverse winding
				output = [
					output[0], output[3], output[2], output[1]
				]
			else
				raise "Error: Invalid symbol for rotation"
			end
			
			return output
		end
		
		def height
			self.t - self.b
		end
		
		def width
			self.r - self.l
		end
		
		
		def to_rectangle
			rect = ThoughtTrace::Rectangle.new(self.width, self.height)
			
			rect[:physics].body.p = CP::Vec2.new(self.l, self.b)
			
			return rect
		end
	end
end