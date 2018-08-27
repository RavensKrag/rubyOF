module CP
	module Shape
		
		
class Rect < Poly
	def initialize(body, width, height, offset=CP::Vec2.new(0,0))
		@width = width
		@height = height
		
		
		super(body, new_geometry(width, height), offset)
	end
	
	# verts named in "x+ right, y+ up" coordinate space
	[:top_left, :top_right, :bottom_right, :bottom_left].each_with_index do |corner, i|
	define_method "#{corner}_vert" do
		self.vert(i)
	end
	end
	
	
	# returns the center of this shape, in local space
	def center
		top_right_vert / 2
	end
	
	# Returns the two verts that specify an edge.
	# Edge is specified using 'resize' grab handle format.
	def edge(grab_handle)
		type, target_indidies = VEC_TO_TRANSFORM_DATA[grab_handle.to_a]
		raise ArgumentError, "#{grab_handle.to_s} is not a valid grab handle" if type.nil?
		raise ArgumentError, "Coordinates do not specify an edge" unless type == :edge
		
		return target_indidies.collect{|i|  self.vert(i)  }
	end
	
	
	
	
	def width
		(self.top_right_vert- self.bottom_left_vert).x
	end
	
	def height
		(self.top_right_vert- self.bottom_left_vert).y
	end
	
	
	
	
	# this method should replace the old 'resize!'
	# Interface to make resizing more humanistic.
	# example:
		#	@entity[:physics].shape.resize!(
		# 		@grab_handle, :world_space, point:@point, lock_aspect:true,
		# 		minimum_dimension:MINIMUM_DIMENSION, limit_by: :smaller
		# 	)
	def resize!(grab_handle, coordinate_space=nil, point:nil, delta:nil, minimum_dimension:1, lock_aspect:false, limit_by:nil)
		raise ArgumentError, "Must specify a grab handle vector" unless grab_handle.is_a? CP::Vec2
		# NOTE: no member functions check to make sure that the handle passed to them is non-nil. This is a problem, as you sometimes fall through the entire function this way.
		
		raise ArgumentError, "Declare point OR delta, not both." if point and delta
		raise ArgumentError, "Must declare either point OR delta." unless point or delta
		
		unless [:world_space, :local_space].include?(coordinate_space)
			raise ArgumentError, "Coordinate space must either be :world_space or :local_space" 
		end
		
		
		if point
			if lock_aspect
				point = self.body.world2local(point) if coordinate_space == :world_space
				
				a = grab_handle
				b = point
				c = minimum_dimension
				
				resize_to_local_point_locked_aspect!(a,b,c, limit_by:limit_by)
			else
				a = grab_handle
				b = point
				c = minimum_dimension
				
				case coordinate_space
					when :world_space
						resize_to_point!(a,b,c)
					when :local_space
						resize_to_local_point!(a,b,c)
				end
			end
		else # delta
			a = grab_handle
			b = delta
			c = minimum_dimension
			resize_by_delta!(a,b,c)
		end
	end
	
	
	# vert order: bottom left, bottom right, top right, top left (Gosu render coordinate space)
	# NOTE: may want to just use neg and pos so you don't have to specify what is "UP"
	
	# all 9 slices in order:
	# top to bottom, left to right
	VEC_TO_TRANSFORM_DATA = {
		[-1.0, -1.0] => [:vert,     [3]],
		[ 0.0, -1.0] => [:edge,     [2,3]],
		[ 1.0, -1.0] => [:vert,     [2]],
		[-1.0,  0.0] => [:edge,     [3,0]],
		[ 0.0,  0.0] => [:center,   [0,1,2,3]],
		[ 1.0,  0.0] => [:edge,     [1,2]],
		[-1.0,  1.0] => [:vert,     [0]],
		[ 0.0,  1.0] => [:edge,     [0,1]],
		[ 1.0,  1.0] => [:vert,     [1]]
	}
	# NOTE: list numbers as floats, not ints, because that's how CP::Vec2 data is stored.
	
	# NOTE: little bit of jitter on counter-steering
	
	# NOTE: notice that grab handles are always relative to the Shape's coordinate space
	
	
	# Transform the rectangle based on a transformation delta
	def resize_by_delta!(grab_handle, delta, minimum_dimension=1)
		type, target_indidies = VEC_TO_TRANSFORM_DATA[grab_handle.to_a]
		
		
		verts = self.verts()
		original_verts = verts.collect{ |vec|  vec.clone  }
		
		case type
			when :edge
				# scale the edge along the axis shared by it's verts
				a,b = target_indidies.collect{|i| verts[i] }
				axis = ( a.x == b.x ? :x : :y )
				
				
				target_indidies.each do |i|
					eval "verts[#{i}].#{axis} += delta.#{axis}"
				end
				
			when :vert
				# move one main vert on both axis,
				# and two secondary verts one axis each, in accordance with the main one.
				i = target_indidies.first
				
				main  = verts[i]
				
				other = verts.select.with_index{ |vert, index| index != i  }
				a = other.find{ |vert|  vert.x == main.x }
				b = other.find{ |vert|  vert.y == main.y }
				
				
				
				main.x += delta.x
				main.y += delta.y
				a.x += delta.x
				b.y += delta.y
			when :center
				# do nothing
		end
		
		
		clamp_dimensions!(verts, original_verts, minimum_dimension)
		commit_verts!(verts)
	end
	
	
	# Transform by moving a grab handle to match up with a point in local space
	# (as best as possible while maintaining the properties of a rectangle)
	# 
	# code is pretty much identical to #resize_by_delta!()
	# except it uses '=' instead of '+=' to transform the verts
	# (and obviously it uses 'point' instead of 'delta')
	def resize_to_local_point!(grab_handle, point, minimum_dimension=1)
		type, target_indicies = VEC_TO_TRANSFORM_DATA[grab_handle.to_a]
		
		
		verts = self.verts()
		original_verts = verts.collect{ |vec|  vec.clone  }
		
		case type
			when :edge
				# scale the edge along the axis shared by it's verts
				a,b = target_indicies.collect{|i| verts[i] }
				axis = ( a.x == b.x ? :x : :y )
				
				
				target_indicies.each do |i|
					eval "verts[#{i}].#{axis} = point.#{axis}"
				end
				
			when :vert
				# move one main vert on both axis,
				# and two secondary verts one axis each, in accordance with the main one.
				i = target_indicies.first
				
				main  = verts[i]
				
				other = verts.select.with_index{ |vert, index| index != i  }
				a = other.find{ |vert|  vert.x == main.x }
				b = other.find{ |vert|  vert.y == main.y }
				
				
				
				main.x = point.x
				main.y = point.y
				a.x = point.x
				b.y = point.y
			when :center
				# do nothing
		end
		
		
		clamp_dimensions!(verts, original_verts, minimum_dimension)
		commit_verts!(verts)
	end
	
	# Transform by moving a grab handle to match up with a point in world space
	# (assume point is global, rather than local)
	def resize_to_point!(grab_handle, point, minimum_dimension=1)
		point = self.body.world2local(point)
		resize_to_local_point!(grab_handle, point, minimum_dimension)
	end
	
	# NOTE: parameter 'limit_by' specifies which side should limit the scaling of the rectangle.
	def resize_to_local_point_locked_aspect!(grab_handle, point, minimum_dimension=1,limit_by:nil)
		type, target_indicies = VEC_TO_TRANSFORM_DATA[grab_handle.to_a]
		
		new_verts = self.verts
		
		
		# store original dimensions before any transforms
		original_width  = self.width
		original_height = self.height
		
		
		# compute minimum dimensions
		limit_by ||= :smaller
		limits = [:smaller, :larger, :width, :height]
		unless limits.include? limit_by
			raise "Must declare kwarg 'limit by' with one of these values: #{limits.inspect}"
		end
		
		
		minimum_x, minimum_y =
			minimum_dimensions(width, height, minimum_dimension, limit_by)
		
		
		
		
		
		
		case type
			when :edge
				# these two lines stolen from CP::Shape::Rect#resize_by_delta!
				a,b = target_indicies.collect{|i| new_verts[i] }
				axis = ( a.x == b.x ? :x : :y )
				
				
				
				# TODO: consider possible problems of dividing delta by two. Should you use integer division? The underlying measurements are pixels, so what happens when you divide in half? Will you ever lose precision?
				
				
				# -----
				# Compare these two ratios:
				# > minimum dimension calculation
				# > scale the secondary axis
				# 
				# The two ratios are similarly calculated, but you can't reuse the same variable.
				# The top ratio is based on the which side is longer, 
				# but the bottom ratio is based on which side is being directly manipulated.
				# -----
				
				
				
				# Scale the edge along the axis shared by it's verts
				# Then, scale along the other axis
				if axis == :x
					# primary x
					self.resize_to_local_point!(grab_handle, point, minimum_x)
					
					
					# secondary y
					ratio = original_height / original_width
					
					new_width  = self.width
					new_height = new_width * ratio
					
					delta = new_height - original_height
					
					
					a = CP::Vec2.new(0,  1)
					b = CP::Vec2.new(0, -1)
					self.resize_by_delta!(a, a*delta/2, minimum_y)
					self.resize_by_delta!(b, b*delta/2, minimum_y)
				else # axis == :y
					# primary y
					self.resize_to_local_point!(grab_handle, point, minimum_y)
					
					
					# secondary x
					ratio = original_width / original_height
					
					new_height = self.height
					new_width = new_height * ratio
					
					delta = new_width - original_width
					
					
					a = CP::Vec2.new( 1, 0)
					b = CP::Vec2.new(-1, 0)
					self.resize_by_delta!(a, a*delta/2, minimum_x)
					self.resize_by_delta!(b, b*delta/2, minimum_x)
				end
				
				
				
			when :vert
				# should perform calculations completely within local space
				# (this allows for advanced coordinate space manipulations, ex: body rotation)
				
				center = self.center
				vert = new_verts[target_indicies.first]
				diagonal = (vert - center).normalize
				
				
				point -= center
					# perform projection relative to center
					# (  this coordinate space can not be rotated or skewed
					#    so you can get in / out via translation only   )
					point = point.project(diagonal)
				point += center
				
				# all calculations in local space
				# some calculations local to center, rather than local origin
				
				
				
				# scale each axis separately, so each can be clamped independently
				self.resize_to_local_point!(CP::Vec2.new(grab_handle.x,0), point, minimum_x)
				self.resize_to_local_point!(CP::Vec2.new(0,grab_handle.y), point, minimum_y)
				
				
			when :center
				# nothing
		end
	end
	
	
	# Resize the rectangle to become the shape specified by this bounding box
	# NOTE: VERY BRITTLE. Will only work with axis-aligned rectangles.
	# (Groups as always axis aligned, so this is primarly for groups. Putting this code in this location may prove to be a bad decision.)
	def resize_by_bb!(bb)
		# this seems to only have a problem with the first selection?
		# after that, the code seems to work totally fine.
		
		
		# [
		# 	[CP::Vec2.new(-1,  0),   CP::Vec2.new(bb.l,0)],
		# 	[CP::Vec2.new( 0, -1),   CP::Vec2.new(0,bb.b)],
		# 	[CP::Vec2.new( 1,  0),   CP::Vec2.new(bb.r,0)],
		# 	[CP::Vec2.new( 0,  1),   CP::Vec2.new(0,bb.t)]
		# ].each do |a,b|
		# 	self.resize!(
		# 		a, :world_space, point:b, lock_aspect:false
		# 	)
		# end
		
		
		# maybe coordinate space conversion is making this screwy?
		# still not totally sure what corner is being used for the origin point any more
		# because I changed the notion of the Rect local coordinate space so many times.
		
		# (really want global y+ to be up, but currently it is down)
		# (so will likely have to change everything again)
		
		
		
		
		
		# following calculation to get verts is from Rect#new_geometry (this file, further down)
		# cw winding
		verts = [
			CP::Vec2.new(bb.l, bb.t),
			CP::Vec2.new(bb.r, bb.t),
			CP::Vec2.new(bb.r, bb.b),
			CP::Vec2.new(bb.l, bb.b)
		]
		
		# mutate the state of the polygon
		commit_verts!(verts)
		
		
		# # following line is from on BB#to_rectangle
		# self.body.p = CP::Vec2.new(bb.l, bb.b)
	end
	
	
	
	private
	
	def minimum_dimensions(width, height, minimum_dimension, limit_by)
		minimum_x = nil
		minimum_y = nil
		
		limit_by_width = ->(){
			# width limits scaling
			ratio = height / width
			
			minimum_x = minimum_dimension
			minimum_y = minimum_dimension * ratio
		}
		
		limit_by_height = ->(){
			# height limits scaling
			ratio = width / height
			
			minimum_y = minimum_dimension
			minimum_x = minimum_dimension * ratio
		}
		
		case limit_by
			when :smaller
				if width <= height
					limit_by_width[]
				else
					limit_by_height[]
				end
			when :larger
				if width >= height
					limit_by_width[]
				else
					limit_by_height[]
				end
			when :width
				limit_by_width[]
			when :height
				limit_by_height[]
		end
		
		return minimum_x, minimum_y
	end
	
	
	
	def transform_verts!(verts, type, target_indidies)
		case type
			when :edge
				# scale the edge along the axis shared by it's verts
				a,b = target_indidies.collect{|i| verts[i] }
				axis = ( a.x == b.x ? :x : :y )
				
				
				target_indidies.each do |i|
					eval "verts[#{i}].#{axis} += delta.#{axis}"
				end
				
			when :vert
				# move one main vert on both axis,
				# and two secondary verts one axis each, in accordance with the main one.
				i = target_indidies.first
				
				main  = verts[i]
				
				other = verts.select.with_index{ |vert, index| index != i  }
				a = other.find{ |vert|  vert.x == main.x }
				b = other.find{ |vert|  vert.y == main.y }
				
				
				
				main.x += delta.x
				main.y += delta.y
				a.x += delta.x
				b.y += delta.y
			when :center
				# do nothing
		end
	end
	
	# limit minimum size (like a clamp, but lower bound only)
	def clamp_dimensions!(verts, original_verts, minimum_dimension)
		vec = (verts[1] - verts[3])
		width  = vec.x
		height = vec.y
		
		
		verts.zip(original_verts).each do |vert, original|
			[
				[:x, width],
				[:y, height]
			].each do |axis, length|
				
				
				if vert.send(axis) != original.send(axis)
					# vert has been transformed on the given axis
					
					# if the dimension on this axis is too short...
					if length < minimum_dimension
						# counter-steer in the direction of the original vert
						direction = ( vert.send(axis) > original.send(axis) ? 1 : -1 )
						# by an amount that would make the dimension equal the minimum
						delta = minimum_dimension - length
						
						
						eval "vert.#{axis} += #{delta} * #{direction} * -1"
					end
				end
				
				
			end
		end
		
	end
	
	def commit_verts!(new_verts)
		offset = new_verts[3] * -1
		# this vert is by default (0,0) in local space,
		# so you need to restore it to it's default position as the local origin.
		# if you don't, then width / height calculations get weird
		
		self.set_verts!(new_verts, offset)
		self.body.p -= offset
	end
	
	
	
	
	
	
	
	def new_geometry(width, height)
		l = 0
		b = 0
		r = width
		t = height
		
		# cw winding
		verts = [
			CP::Vec2.new(l, t),
			CP::Vec2.new(r, t),
			CP::Vec2.new(r, b),
			CP::Vec2.new(l, b)
		]
		
		# raise "Problem with specified verts." unless CP::Shape::Poly.valid? verts
		
		return verts
	end


			
end
end
end
