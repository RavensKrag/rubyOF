 
module RubyOF
	module CPP_Callbacks

class << self
	private :copyFramebufferByBlit__cpp
	def copyFramebufferByBlit(src_fbo, dst_fbo, buffer_name)
		buffer_flag = 
			case buffer_name
			when :color_buffer
				0b01
			when :depth_buffer
				0b10
			when :both
				0b11
			else
				0x00
			end
		
		return copyFramebufferByBlit__cpp(src_fbo, dst_fbo, buffer_flag)
	end
end


end
end
