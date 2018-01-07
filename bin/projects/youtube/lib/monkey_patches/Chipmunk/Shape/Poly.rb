module CP
	module Shape
		class Poly
			alias :old_init :initialize
			
			attr_reader :offset
			
			def initialize(body, verts, offset=CP::Vec2.new(0,0))
				old_init(body, verts, offset)
				@offset = offset
			end
			
			# Draw poly from verts in world space coordinates
			# Assumes that the poly is convex whole, but that's an assumption built into Chipmunk.
			def draw(color, z=0)
				$window.gl z do
					GL.Enable(GL::GL_BLEND)
					GL.BlendFunc(GL::GL_SRC_ALPHA, GL::GL_ONE_MINUS_SRC_ALPHA)
					
					GL.Begin(GL::GL_TRIANGLE_FAN)
						GL.Color4ub(color.red, color.green, color.blue, color.alpha)
						
						# TODO: Convert coordinates on GPU using local coordinates and transform
						# transform should account for translation and rotation
						self.each_vert do |v|
							vec = self.body.local2world(v)
							
							GL.Vertex2f(vec.x.round, vec.y.round)
						end
					
					GL.End()
				end
			end
			
			# return an array of all vertices
			def verts
				out = Array.new(self.num_verts)
				self.num_verts.times do |i|
					out[i] = self.vert(i)
				end
				
				return out
			end
			
			def area
				CP.area_for_poly self.verts
			end
			
			# return center of this shape in local space
			def center
				verts = each_vert.to_a
				verts.reduce(&:+) / verts.size
			end
			
			
			
			include Enumerable
			
			def each
				self.num_verts.times do |i|
					yield self.vert(i)
				end
			end
			
			# TODO: consider adding a way to iterate over verts in world-space as well
			
			alias :each_vert :each
			alias :each_vert_with_index :each_with_index
			alias :each_vert_with_object :each_with_object
		end
	end
end