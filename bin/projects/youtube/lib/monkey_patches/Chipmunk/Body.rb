module CP
	class Body
		def clone
			b = CP::Body.new(self.mass, self.moment)
			
			# copy all properties that can be set
			b_methods = b.methods
			
			setters = b_methods.grep(/.*=/)
			setters.pop(setters.count - setters.index(:===)) # Discard from "key" to the end
					
			getters = b_methods.select{ |m| setters.include? "#{m}=".to_sym }
			
			
			getters.zip(setters).each do |get, set|
				b.send set, self.send(get)
			end
			
			return b
		end
	end
end