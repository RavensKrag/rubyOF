module GLM

class << self
	private :toMat4__quat
	def toMat4(arg)
		case arg
		when GLM::Quat
			return toMat4__quat(arg)
		end 
	end
	
	
	private :quat_cast__mat3, :quat_cast__mat4
	def quat_cast(arg)
		case arg
		when GLM::Mat3
			return quat_cast__mat3(arg)
		when GLM::Mat4
			return quat_cast__mat4(arg)
		end
	end
	
	private :inverse__mat3, :inverse__mat4, :inverse__quat
	def inverse(arg)
		case arg
		when GLM::Mat3
			return inverse__mat3(arg)
		when GLM::Mat4
			return inverse__mat4(arg)
		when GLM::Quat
			return inverse__quat(arg)
		end
	end
	
end

end
