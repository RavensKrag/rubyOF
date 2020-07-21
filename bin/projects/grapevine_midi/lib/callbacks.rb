module RubyOF
	module Project


class ColorPicker
	attr_reader :color
	
	private :getColorPtr
	
	def setup
		puts ">>>>>>>>>>  initializing color picker interface"
		
		# p getColorPtr()
		@color = getColorPtr()
	end
end


end
end
