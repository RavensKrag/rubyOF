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
	
	'window',
	'color',
	'graphics',
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
	
	
	OF_MATRIX_MODES = [
		:modelview,
		:projection,
		:texture
	]	
	
	alias :ofSetMatrixMode__cpp :ofSetMatrixMode
	private :ofSetMatrixMode__cpp
	def ofSetMatrixMode(mode)
		i = OF_MATRIX_MODES.index(mode)
		
		raise ArgumentError, "Given matrix mode #{mode.inspect} is not a valid matrix mode. Please use one of the following: #{OF_MATRIX_MODES.inspect}" if i.nil?
		
		ofSetMatrixMode__cpp(i)
	end
	
	
	
	
	# do not pass material to block, as material uniforms must all be set before the material is bound
	def using_material(material) # &block
	  material.begin

	  yield

	  material.end
	end


	# TODO: add exception handling here, so gl state set by binding shader and textures doesn't leak
	def using_shader(shader) # &block
	  shader.begin

	  yield shader

	  shader.end
	end

	# TODO: add exception handling here, so gl state set by binding shader and textures doesn't leak
	def using_textures(*texture_list)
	  texture_list.each_with_index do |tex,i|
	    tex.bind(i) unless tex.nil?
	  end

	  yield *texture_list

	  texture_list.each_with_index do |tex,i|
	    tex.unbind(i) unless tex.nil?
	  end
	end


end


class Mesh
	alias :setMode__cpp :setMode
	private :setMode__cpp
	
	OF_PRIMITIVES = [
		:triangles,
		:triangle_strip,
		:triangle_fan,
		:lines,
		:line_strip,
		:line_loop,
		:points,
	]
	
	def setMode(mode)
		i = OF_PRIMITIVES.index(mode)
		
		raise ArgumentError, "Given mesh mode #{mode.inspect} is not a valid mesh mode. Please use one of the following: #{OF_PRIMITIVES.inspect}" if i.nil?
		
		setMode__cpp(i)
	end
	
	
	
	private :draw__cpp
	
	OF_POLY_RENDER_MODE = [
		:points,
		:wireframe,
		:fill
	]
	
	def draw(render_mode=:fill)
		i = OF_POLY_RENDER_MODE.index(render_mode)
		
		raise ArgumentError, "Given poly render mode #{mode.inspect} is not a valid mesh mode. Please use one of the following: #{OF_POLY_RENDER_MODE.inspect}" if i.nil?
		
		draw__cpp(i)
	end
end

class VboMesh
	private :draw_instanced__cpp
	
	def draw_instanced(instance_count, render_mode=:fill)
		i = OF_POLY_RENDER_MODE.index(render_mode)
		
		raise ArgumentError, "Given poly render mode #{mode.inspect} is not a valid mesh mode. Please use one of the following: #{OF_POLY_RENDER_MODE.inspect}" if i.nil?
		
		draw_instanced__cpp(i, instance_count)
	end
end




class Color
	CHANNEL_MAX = 255
	
	def to_a
		return [self.r,self.g,self.b,self.a]
	end
	
	def rgba=(color_array)
		raise ArgumentError, "Expected an array of size 4 that encodes rgba color data (each channel should be an integer, with a maximum of #{CHANNEL_MAX} per channel)" unless color_array.size == 4
		
		self.r,self.g,self.b,self.a = color_array
	end
	
	class << self
		def rgba(color_array)
			color = self.new
			color.rgba = color_array
			
			return color
		end
		
		def rgb(color_array)
			raise ArgumentError, "Expected an array of size 3 that encodes rgb color data (each channel should be an integer, with a maximum of #{CHANNEL_MAX} per channel)" unless color_array.size == 3
			
			# Must add, can't push because arrays in Ruby are objects
			# and all objects in Ruby are reference types.
			# Thus, the array provided will always be an in/out parameter.
			self.rgba(color_array + [CHANNEL_MAX])
		end
		
		def hex(hex)
			color = self.new
			color.set_hex(hex, CHANNEL_MAX)
			return color
		end
		
		def hex_alpha(hex, alpha)
			color = self.new
			color.set_hex(hex, alpha)
			return color
		end
	end
end

class FloatColor
	CHANNEL_MAX = 1
	
	def to_a
		return [self.r,self.g,self.b,self.a]
	end
	
	def rgba=(color_array)
		raise ArgumentError, "Expected an array of size 4 that encodes rgba color data (each channel should be an float, in the range 0 to 1)" unless color_array.size == 4
		
		self.r,self.g,self.b,self.a = color_array
	end
	
	class << self
		def rgba(color_array)
			color = self.new
			color.rgba = color_array
			
			return color
		end
		
		def rgb(color_array)
			raise ArgumentError, "Expected an array of size 3 that encodes rgb color data (each channel should be an float, in the range 0 to 1)" unless color_array.size == 3
			
			# Must add, can't push because arrays in Ruby are objects
			# and all objects in Ruby are reference types.
			# Thus, the array provided will always be an in/out parameter.
			self.rgba(color_array + [CHANNEL_MAX])
		end
		
		def hex(hex)
			color = self.new
			color.set_hex(hex, CHANNEL_MAX)
			return color
		end
		
		def hex_alpha(hex, alpha)
			color = self.new
			color.set_hex(hex, alpha)
			return color
		end
	end
end

class ShortColor
	CHANNEL_MAX = 65535
	
	def to_a
		return [self.r,self.g,self.b,self.a]
	end
	
	def rgba=(color_array)
		raise ArgumentError, "Expected an array of size 4 that encodes rgba color data (each channel should be an float, in the range 0 to 1)" unless color_array.size == 4
		
		self.r,self.g,self.b,self.a = color_array
	end
	
	class << self
		def rgba(color_array)
			color = self.new
			color.rgba = color_array
			
			return color
		end
		
		def rgb(color_array)
			raise ArgumentError, "Expected an array of size 3 that encodes rgb color data (each channel should be an float, in the range 0 to 1)" unless color_array.size == 3
			
			# Must add, can't push because arrays in Ruby are objects
			# and all objects in Ruby are reference types.
			# Thus, the array provided will always be an in/out parameter.
			self.rgba(color_array + [CHANNEL_MAX])
		end
		
		def hex(hex)
			color = self.new
			color.set_hex(hex, CHANNEL_MAX)
			return color
		end
		
		def hex_alpha(hex, alpha)
			color = self.new
			color.set_hex(hex, alpha)
			return color
		end
	end
end

	
class Shader
	# private :load_oneNameVertAndFrag, :load_VertFragGeom
	
	alias :old_init :initialize
	def initialize
		old_init()
		
		@livecoding_timestamp = nil
	end
	
	private :load_shaders__cpp
	def load_glsl(*args)
		
		if(args.length <= 3)
			p args.map{|x| x.to_s }
			load_shaders__cpp(args.map{|x| x.to_s })
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
	
	
	# dynamic reloading of compositing shader
	# (code copied from RenderBatch#reload_shaders)
	def live_load_glsl(vert_shader_path, frag_shader_path, geom_shader_path=nil)
		paths =
			[
				vert_shader_path,
				frag_shader_path,
				geom_shader_path
			]
			.compact
			.collect{ |path| Pathname.new path  }
		
		# p @livecoding_timestamp
		
		if(@livecoding_timestamp.nil? || 
			paths.any?{|f| f.mtime > @livecoding_timestamp }
		)
			puts "reloading alpha compositing shaders..."
			
			self.load_glsl(*paths)
			
			# careful - these shaders don't go through the same pre-processing step as the ones in Material, so special directives like these:
			# 
			#    %glsl_version%
			#    %extensions%
			# 
			# won't get applied, but #define statements will.
			# 
			# (the % preprocessing is defined in ofGLProgrammableRenderer.cpp)
			# (search for ofStringReplace)
			# 
			# (#define preprocessing is defined in ofShader.cpp)
			# (search for regex_replace)
			
			@livecoding_timestamp = Time.now
		end
		
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

class FloatPixels
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
	
	WRAP_MODE = [
		:clamp_to_edge,
		:clamp_to_border,
		:mirrored_repeat,
		:repeat,
		:mirror_clamp_to_edge
	]
	
	private :setTextureWrap__cpp
	def wrap_mode(vertical: nil, horizontal: nil)
		i = WRAP_MODE.index(vertical)
		j = WRAP_MODE.index(horizontal)
		
		
		# TODO: finish this error checking message
		# TODO: implement message for horizontal too
		
		msg = []
		
		if i.nil?
			msg << "Vertical texture wrap mode #{vert_mode.inspect} is not a valid mesh mode."
		end
		if j.nil?
			msg << "Horizontal texture wrap mode #{horiz_mode.inspect} is not a valid mesh mode."
		end
		
		unless msg.empty?
			msg << "These are the valid texture wrap modes: #{WRAP_MODE.inspect}"
			
			raise ArgumentError, msg.join("\n")
		end
		
		
		setTextureWrap__cpp(i,j)
	end
	
	
	MIN_FILTER_MODES = [
		:nearest,
		:linear,
		:nearest_mipmap_nearest,
		:linear_mipmap_nearest,
		:nearest_mipmap_linear,
		:linear_mipmap_linear 
	]
	
	MAG_FILTER_MODES = [
		:nearest,
		:linear
	]
	
	private :setTextureMinMagFilter__cpp
	def filter_mode(min: nil, mag: nil)
		i = MIN_FILTER_MODES.index(min)
		j = MAG_FILTER_MODES.index(mag)
		
		msg = []
		
		if i.nil?
			msg << "Texture filter min mode #{min.inspect} is not a valid mesh mode."
			msg << "These are the valid min filter modes: #{MIN_FILTER_MODES.inspect}"
		end
		if j.nil?
			msg << "Texture filter mag mode #{mag.inspect} is not a valid mesh mode."
			msg << "These are the valid mag filter modes: #{MAG_FILTER_MODES.inspect}"
		end
		
		unless msg.empty?
			raise ArgumentError, msg.join("\n")
		end
		
		
		setTextureMinMagFilter__cpp(i,j)
	end
	
	
	private :loadData_Pixels, :loadData_FloatPixels
	def load_data(px_data)
		case px_data
		when Pixels
			loadData_Pixels(px_data)
		when FloatPixels
			loadData_FloatPixels(px_data)
		end
	end
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
	
	
	
	DEFAULT_SETTINGS = {
		:width => 0,
		:height => 0,
		:numColorbuffers => 1,
		
		:useDepth => false,
		:useStencil => false,
		:depthStencilAsTexture => false,
		:textureTarget => Gl::GL_TEXTURE_2D,
		:internalformat => Gl::GL_TEXTURE_2D,
		:depthStencilInternalFormat => GL::GL_DEPTH_COMPONENT24,
		:wrapModeHorizontal => GL::GL_CLAMP_TO_EDGE,
		:wrapModeVertical => GL::GL_CLAMP_TO_EDGE,
		:minFilter => GL::GL_LINEAR,
		:maxFilter => GL::GL_LINEAR,
		:numSamples => 0
	}
	
	Settings = Struct.new(*DEFAULT_SETTINGS.keys) do 
		def initialize()
			super(*DEFAULT_SETTINGS.values)
		end
	end
	
	# NOTE: While in OpenGL the names are "min" and "mag"
	#       (as in magnify)
	#       there seems to be a 'typo' of sorts in OpenFrameworks,
	#       so the proper name for this field is 'max' instead of 'mag'
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

