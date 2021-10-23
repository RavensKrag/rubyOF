module RubyOF

class Pixels
	# private :setColor_i, :setColor_xy
	
	def setColor(x,y, c)
		setColor_xy(x,y, c)
	end
	
	def []=(i, c)
		setColor_i(i, c)
	end
	
	def color_at(x,y)
		getColor_xy(x,y)
	end
	
	def flip_vertical
		flip(false, true)
	end
	
	def flip_horizontal
		flip(true, false)
	end
	
	def flip_both
		flip(true, true)
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
	
	def color_at(x,y)
		getColor_xy(x,y)
	end
	
	def flip_vertical
		flip(false, true)
	end
	
	def flip_horizontal
		flip(true, false)
	end
	
	def flip_both
		flip(true, true)
	end
end


end
