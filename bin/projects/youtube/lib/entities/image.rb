class Image < Entity
	attr_accessor :z
	
	def initialize(image)
		# Use default position CP::Vec2.new(0,0)
		@z = 0
		
		@image = image
		
		# TODO: make sure there is a way to get width / height data out of an image. oF has this capability, but I need to make sure that the functions are bound.
		
		
		# TODO: figure out what the proper initial values for Body are
		@body  = CP::Body.new(1,1)
		
		offset=CP::Vec2.new(0,0)
		width  = @image.width
		height = @image.height
		@shape = CP::Shape::Rect.new(@body, width, height, offset)
		
	end
	
	# TODO: figure out if an Image entity should be able to take a new image filepath.
		# maybe you need that if you want to apply the same crop to a new image? like, slotting in updated image data into a layout? but then wouldn't you just need to reload the file? not exactly clear or what I need yet.
	
	
	
	def serialize
		serialized = Serialized.new
		
		
		return serialized
	end
	
	def deserialize(serialized)
		@id = serialized.id
		
		serialized.data
	end
	
	
	
	
	def update
		
	end
	
	
	# NOTE: texture binding is handed by the render queue in Space
	def texture
		# No textures are returned for the general purpose Image class.
		
		# If you need to bind one texture and draw from it many times (e.g. sprite atalassing) then you need to make a separate Entity type for that.
	end
	
	def draw
		@image.draw(@body.p.x, @body.p.y, @z)
	end
end 
