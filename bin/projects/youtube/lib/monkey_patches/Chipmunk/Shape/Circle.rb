module CP
	module Shape
		class Circle
			def draw(color, z=0)
				$window.gl z do
					GL.Enable(GL::GL_BLEND)
					GL.BlendFunc(GL::GL_SRC_ALPHA, GL::GL_ONE_MINUS_SRC_ALPHA)
					
					GL.PushMatrix()
					# TODO: consider using integer transforms
					GL.Translatef(self.body.p.x, self.body.p.y, 0)
						GL.Begin(GL::GL_TRIANGLE_FAN)
							GL.Color4ub(color.red, color.green, color.blue, color.alpha)
							# 
							# radius_rotation
							midpoint_circle
						GL.End()
					GL.PopMatrix()
				end
			end
			
			def area
				CP.area_for_circle 0, self.radius # inner, outer (order doesn't seem to matter)
			end
			
			
			# return center of this shape in local space
			def center
				# NOTE: I'm not totally sure that this will work in general, because of the shape offset. However, it should work fine within the system defined by ThoughtTrace
				CP::Vec2.new(0,0)
			end
			
			private
			
			def radius_rotation
				iterations = 60 # seems like high iterations cause crashes?
				# iterations = 12
				
				
				rotation_angle = 2*Math::PI / iterations # radians
				rotation_vector = CP::Vec2.for_angle rotation_angle
				
				
				vec = CP::Vec2.new(self.radius, 0)
				
				# center
				GL.Vertex2f(0, 0)
				
				# verts on the edge of the circle
				(iterations+1).times do # extra iteration to loop back to start
					GL.Vertex2f(vec.x, vec.y)
					
					vec = vec.rotate rotation_vector
				end
			end
			
			def midpoint_circle
				# debug_print = ->(list){
				# 	puts "---"
				# 	puts list.collect{ |p| p.to_s  }
				# }
				
				# # note:
				# # step = length * 2 / r
				# # (kinda want to configure based on the number of ticks per octant, not, the step value)
				
				# length = 5
				
				# r = self.r.round
				# step = [length * 2 / r, 1].max # needs to be at least 1
				
				step = 1
				
				
				r = self.r.round
				
				q_half = Array.new(r / 2 / step)
					x = r
					y = 0
					r2 = r**2
					
					q_half.each_index do |i|
						x -= step if ((x**2) + (y**2)) > r2
						y += step
						
						q_half[i] = CP::Vec2.new(x, y)
					end
				
				
				q1    = q_half + q_half.collect{|p| CP::Vec2.new( p.y,  p.x) }.reverse!
				
				q12   = q1  + q1.collect{  |p|      CP::Vec2.new(-p.x,  p.y) }.reverse!
				
				q1234 = q12 + q12.collect{ |p|      CP::Vec2.new( p.x, -p.y) }.reverse!
				
				
				# debug_print[q1234]
				
				
				GL.Vertex2f(0, 0) # center
				
				q1234 << q1234.first # loop all the way around to first point
				q1234.each do |vec|
					GL.Vertex2f(vec.x.round, vec.y.round)
				end
			end
			
		end
	end
end