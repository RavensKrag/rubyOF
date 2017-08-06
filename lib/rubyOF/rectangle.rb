module RubyOF

# This is basically the bounding box class
class Rectangle
	def to_s
		"<x: #{self.x}, y: #{self.y}, width: #{self.width}, height: #{self.height} | (#{self.left}, #{self.bottom}) -> (#{self.right}, #{self.top})>"
	end
	
	def inspect
		super()
	end
	
	# convert to a Chipmunk CP::BB object
	def to_cpbb
		return CP::BB.new(self.left, self.bottom, self.right, self.top)
	end
	
	# Ruby-level wrapper to replicate the overloaded C++ interface.
	def inside?(*args)
		signature_error = "Specify a point(two floats, or one Point), line(two Point), or rectangle(one Rectangle)."
		
		raise "Wrong arity. " + signature_error unless args.length == 1 or args.length == 2
		
		
		
		case args.length
			when 1
				if klass.is_a? Point
					self.inside_p *args
				elsif klass.is_a? Rectangle
					self.inside_r *args
				end
				
				# Will have exited by this point, unless there was an error.
				raise "One argument given. Expected Point or Rectangle, but recieved #{args[0].class.inspect} instead. " + signature_error
			when 2
				if args[0].class == args[1].class
					klass = args.first.class
					if klass.is_a? Point
						# a line, specified by two points
						self.inside_pp *args
					elsif klass.is_a? Float
						# a point in space, specified by two floats
						self.inside_xy *args 
					end
				end
				
				# Will have exited by this point, unless there was an error.
				raise "Two arguments given. Expected both to be Point or both to be Float, but recieved #{[args[0].class, args[1].class].inspect} instead. " + signature_error
		end
	end
	
	
	def intersects?(*args)
		signature_error = "Specify a line(two Point) or a rectangle(one Rectangle)."
		
		raise "Wrong arity. " + signature_error unless args.length == 1 or args.length == 2
		
		
		case args.length
			when 1
				raise "Expected a Rectangle, but recieved #{args[0].class.inspect} instead. " + signature_error unless args[0].is_a? Rectangle
				
				self.intersects_r *args
				
			when 2
				raise "Expected two Point objects, but recieved #{[args[0].class, args[1].class].inspect} instead. " + signature_error unless args.all?{ |a| a.is_a? Point } 
				
				self.intersects_pp *args
		end
	end
	
	
	alias :intersect? :intersects?
end

end
