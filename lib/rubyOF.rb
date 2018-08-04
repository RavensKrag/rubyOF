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

