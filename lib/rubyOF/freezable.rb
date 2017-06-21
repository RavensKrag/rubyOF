module Oni


module Freezable
	def freeze
		# self.class.class_eval do # <-- this changes all instances
		meta_eval do # <-- this only effects one instance, "singleton style" 
			# this first part performs the actual freeze:
			#   select the public instance methods that allow mutation,
			#   and overwrite them, so they are blocked.
			method_symbols = self.instance_methods
			
			tokens = %w[= set]
			
			mutators = 
				method_symbols.select{ |sym| tokens.any?{ |token|
					sym.to_s.include? token
				}}
			
			mutators.each do |sym|
				define_method sym do |*args|
					raise RuntimeError, "ERROR: Can't modify frozen Color."
				end
			end
			
			# redefine frozen for this class, to return true
			define_method :frozen? do
				return true
			end
		end
		
		return self
	end
	
	def frozen?
		return false
	end
end



end
