module RubyOF

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


end
