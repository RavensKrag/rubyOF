module GLM

class Vec3
	include RubyOF::Freezable
	
	def to_s
		format = '%.03f'
		x = format % self.x
		y = format % self.y
		z = format % self.z
		
		return "(#{x}, #{y}, #{z})"
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
	%w[x y z].each_with_index do |component, i|
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
	
	
	# discards the Z component.
	def to_cpvec2
		return CP::Vec2.new(self.x, self.y)
	end
end

end
