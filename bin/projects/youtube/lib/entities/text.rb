class Text < Entity
	include RubyOF::Graphics 
	
	attr_accessor :z
	attr_accessor :text_color
	
	def initialize(font, string)
		# Use default position CP::Vec2.new(0,0)
		@z = 0
		
		@string = string
		
		@font = font
		x,y = [0,0]
		of_bb = @font.string_bb(@string,x,y, vflip=true)
		# ^ oF returns a Rectangle object, which has properties x,y,width,height
		
		
		
		@text_color = RubyOF::Color.new.tap do |c|
			c.r, c.g, c.b, c.a = [255, 0, 0, 255]
		end
		
		
		
		# TODO: figure out what the proper initial values for Body are
		@body  = CP::Body.new(1,1)
		
		offset=CP::Vec2.new(0,0)
		width  = of_bb.width
		height = of_bb.height
		@shape = CP::Shape::Rect.new(@body, width, height, offset)
		
	end
	
	# can't use attr_accessor, because I need to perform other actions on set
	# (TODO: consider using metaprogramming to make this cleaner?)
	def font
		return @font
	end
	
	def font=(new_font)
		@font = new_font
		
		
		x,y = [0,0]
		of_bb = @font.getStringBoundingBox(@string,x,y)
		# ^ oF returns a Rectangle object, which has properties x,y,width,height
		
		# TODO: need to reshape the rectangle in @shape as well
		# (reshape existing rather than creating a completely new object)
	end
	
	
	
	def serialize
		serialized = Serialized.new
		
		serialized.id = @id
		
		return serialized
	end
	
	def deserialize(serialized)
		@id = serialized.id
		
		font, string = serialized.data
		# TODO: how do I serialize a font? can't just save the ruby-level font object. How would I reinitiailze the font? Do I need some sort of resource manager?
		
		
		font_manager['font_name'] # => Font
		# requirements:
			# + return font from cache if it exists
			# + if font with that name does not exist, load it and put in cache, then return it
		# TODO: need to figure how size and character set will be specified
	end
	
	
	def update
		x,y = [0,0]
		vflip = true
		@text_mesh ||= font.get_string_mesh(@string, x,y, vflip)
	end
	
	
	# NOTE: texture binding is handed by the render queue in Space
	def texture
		@font.font_texture
	end
	
	def draw
		# TODO: need to cluster fonts by their font texture, otherwise rendering becomes inefficent
		ofPushMatrix()
		ofPushStyle()
			ofTranslate(@body.p.x, @body.p.y, @z)
			
			ofSetColor(@text_color)
			@text_mesh.draw()
		ofPopStyle()
		ofPopMatrix()
	end
end 
