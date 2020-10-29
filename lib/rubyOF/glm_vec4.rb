module GLM

class Vec4
	include RubyOF::Freezable
	
	def to_s
		format = '%.03f'
		w = format % self.w
		x = format % self.x
		y = format % self.y
		z = format % self.z
		
		return "(#{w}, #{x}, #{y}, #{z})"
	end
	
	def inspect
		super()
	end
	
	
	
	# hide C++ level helper methods
	private :get_component
	private :set_component
	
	
	# get / set value of a component by numerical index
	def [](i)
		return get_component(i)
	end
	
	def []=(i, value)
		return set_component(i, value.to_f)
	end
	
	
	# get / set values of component by axis name
	%w[w x y z].each_with_index do |component, i|
		# getters
		# (same as array-style interface)
		define_method component do
			get_component(i)
		end 
		
		# setters
		# (use special C++ function to make sure data is written back to C++ land)
		define_method "#{component}=" do |value|
			set_component(i, value.to_f)
		end 
	end
	
	
	# 
	# can automatically convert vec3 and vec2 to CP::Vec2,
	# but no built-in conversion for vec4
	# 
	
	# def to_cpvec2
	# 	return CP::Vec2.new(self.x, self.y)
	# end
end

end
