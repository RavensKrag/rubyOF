puts "RubyOF: loading ruby code"


# === Monkey Patches
class Numeric
	def degrees
		# Assume that this is an angle in radians, and convert to degrees
		# This is so you can write 20.degrees instead of 20.to_deg
		self/ 180.0 * Math::PI
	end
end



# TODO: move this to another file, so if you're not using Chipmunk, that's fine.
module CP
	class Vec2
		def to_ofPoint
			return RubyOF::Point.new(self.x, self.y, 0)
		end
	end
	
	class BB
		def to_ofRectangle
			raise "ERROR: Method is stubbed."
			# return RubyOF::Rectangle.new()
		end
	end
end


# === Standard require for the library
require 'pathname'

lib_dir   = Pathname.new(__FILE__).expand_path.dirname
base_path = lib_dir/'rubyOF'



# include the final dynamic library from each project,
# rather than loading any c-extension stuff at this level.
[
	'version',
	'meta',
	'freezable',
	
	'window',
	'color',
	'graphics',
	'point',
	'rectangle',
	'true_type_font',
	'image',
	
	'button_event_codes',
	
	'resource_manager'
].each do |path|
	require base_path/path
end







module RubyOF


module Graphics
	OF_BLENDMODES = [
		:disabled,
		:alpha,
		:add,
		:multiply,
		:screen,
		:subtract,
	]	
	
	alias :ofEnableBlendMode__cpp :ofEnableBlendMode
	private :ofEnableBlendMode__cpp
	def ofEnableBlendMode(mode)
		i = OF_BLENDMODES.index(mode)
		
		raise ArgumentError, "Given blend mode #{mode.inspect} is not a valid blend mode. Please use one of the following: #{OF_BLENDMODES.inspect}" if i.nil?
		
		ofEnableBlendMode__cpp(i)
	end
end



class Color
	def to_a
		return [self.r,self.g,self.b,self.a]
	end
	
	def rgba=(color_array)
		raise ArgumentError, "Expected an array of size 4 that encodes rgba color data (each channel should be an integer, with a maximum of 255 per channel)" unless color_array.size == 4
		
		self.r,self.g,self.b,self.a = color_array
	end
	
	class << self
		def rgba(color_array)
			color = self.new
			color.rgba = color_array
			
			return color
		end
		
		def rgb(color_array)
			raise ArgumentError, "Expected an array of size 3 that encodes rgb color data (each channel should be an integer, with a maximum of 255 per channel)" unless color_array.size == 3
			
			# Must add, can't push because arrays in Ruby are objects
			# and all objects in Ruby are reference types.
			# Thus, the array provided will always be an in/out parameter.
			self.rgba(color_array + [255])
		end
	end
end
	
class Shader
	# private :load_oneNameVertAndFrag, :load_VertFragGeom
	
	def load(*args)
		
		if(args.length <= 3)
			super(*args)
		else
			raise ArgumentError, 'Expected either one path (vertex and fragment shaders have the same name, i.e. dof.vert and dof.frag) or up to 3 paths: vert,frag,geom (geometry shader is optional)'
		end
		
		# case args.length
		# when 1
		# 	load_oneNameVertAndFrag(args.first)
		# when 2,3
		# 	load_VertFragGeom(*args)
		# else
		# 	raise ArgumentError, 'Expected either one path (vertex and fragment shaders have the same name, i.e. dof.vert and dof.frag) or up to 3 paths: vert,frag,geom (geometry shader is optional)'
		# end
		
	end
end

class Pixels
	# private :setColor_i, :setColor_xy
	
	def setColor(x,y, c)
		setColor_xy(x,y, c)
	end
	
	def []=(i, c)
		setColor_i(i, c)
	end
end

class Texture
	# TODO: clean up the interface for 'draw_wh' and 'draw_pt' bound from C++ layer
	# TODO: perhaps bind other methods of Texture?
	# TODO: consider binding Image as well, so you can CPU and GPU level control from Ruby
	
	# TODO: figure out exactly how the texure memory is being allocated (pick it appart later)
	# TODO: look into texture-atlasing for sprites, in the sprite-drawing libraries
	
	# TODO: figure out how textures can be used with mesh data
end

class Fbo
	private :draw_xy, :draw_xywh
	
	def draw(x,y, w=0,h=0)
		if w == 0 or h ==0
			draw_xy(x,y)
		else
			draw_xywh(x,y,w,h)
		end
	end
	
	Settings = Struct.new(
		:width,
		:height,
		:numColorbuffers,
		
		:useDepth,
		:useStencil,
		:depthStencilAsTexture,
		:textureTarget,
		:internalformat,
		:depthStencilInternalFormat,
		:wrapModeHorizontal,
		:wrapModeVertical,
		:minFilter,
		:maxFilter,
		:numSamples
	)
	# NOTE: While in OpenGL the names are "min" and "mag"
	#       (as in magnify)
	#       there seems to be a 'typo' of sorts in OpenFrameworks,
	#       so the proper name for this field is 'mag'
	# There is a function called ofTextureSetMinMagFilters() though.
end


# TODO: bind graphics functions with typedef instead of the wrapper style. would make it cleaer that the functions are working with global state, and are not actually bound to the window


# class Animation
# 	class Track
# 		def playing?
# 			return !ended?
# 		end
# 	end
# end




end

