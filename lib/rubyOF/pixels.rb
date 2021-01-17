module RubyOF

class Pixels
	# private :setColor_i, :setColor_xy
	
	def setColor(x,y, c)
		setColor_xy(x,y, c)
	end
	
	def []=(i, c)
		setColor_i(i, c)
	end
end

class FloatPixels
	# private :setColor_i, :setColor_xy
	
	def setColor(x,y, c)
		setColor_xy(x,y, c)
	end
	
	def []=(i, c)
		setColor_i(i, c)
	end
end


end
