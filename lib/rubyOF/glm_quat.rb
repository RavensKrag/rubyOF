module GLM

class Quat
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
	
	
	# 
	# glm::quat internal memory order is (x,y,z,w)
	# but the constructor specifies (w,x,y,z)
	# and glm::string_cast uses (w,x,y,z)
	# Therefore, direct memory access should not be allowed from Ruby
	# and all interactions with quaternions should be done through the
	# named component interface
	# 
	# src: https://stackoverflow.com/questions/48348509/glmquat-why-the-order-of-x-y-z-w-components-are-mixed
	
	
	# 
	# no numerical index interface for Quaternion,
	# unlike the other vector types
	# see above for explanation.
	# 
	
	# # get / set value of a component by numerical index
	# def [](i)
	# 	return get_component(i)
	# end
	
	# def []=(i, value)
	# 	return set_component(i, value.to_f)
	# end
	
	
	# get / set values of component by axis name
	%w[x y z w].each_with_index do |component, i|
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
