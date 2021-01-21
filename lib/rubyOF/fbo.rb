module RubyOF


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


end
