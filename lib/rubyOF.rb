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
		def to_glm
			return GLM::Vec2.new(self.x, self.y)
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
	
	'glm_vec2',
	'glm_vec3',
	'glm_vec4',
	'glm_quat',
	'glm_mat4',
	'glm',
	
	'color',
	'graphics',
	'rectangle',
	'true_type_font',
	
	'pixels',
	'texture',
	'image',
	'mesh',
	'fbo',
	'shader',
	'node',
	
	'rb_app',
	
	'button_event_codes',
	'resource_manager'
].each do |path|
	require base_path/path
end








# TODO: bind graphics functions with typedef instead of the wrapper style. would make it cleaer that the functions are working with global state, and are not actually bound to the window


# class Animation
# 	class Track
# 		def playing?
# 			return !ended?
# 		end
# 	end
# end
