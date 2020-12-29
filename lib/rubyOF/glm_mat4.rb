module GLM

class Mat4
	# include RubyOF::Freezable
	
	def to_s
		msg = [
			"<Mat4 (column major) > (",
			"  (#{self[0].to_a.map{|x| '%.03f' % x }.join(', ')})",
			"  (#{self[1].to_a.map{|x| '%.03f' % x }.join(', ')})",
			"  (#{self[2].to_a.map{|x| '%.03f' % x }.join(', ')})",
			"  (#{self[3].to_a.map{|x| '%.03f' % x }.join(', ')})",
			")>"
		]
		return msg.join("\n")
	end
	
	def inspect
		super()
	end
	
	
	def self.new(*args)
		# puts "args override"
		case args.length
		when 1
			# one scalar
			
			# vendor/apothecary/glm/include/glm/detail/type_mat4x4.inl:38
			# GLM_FUNC_QUALIFIER GLM_CONSTEXPR mat<4, 4, T, Q>::mat(T const& s)
			x = args.first
			if x.is_a? Float
				vectors = [
					GLM::Vec4.new(x,0,0,0),
					GLM::Vec4.new(0,x,0,0),
					GLM::Vec4.new(0,0,x,0),
					GLM::Vec4.new(0,0,0,x)
				]
				return super(*vectors)
				# return self
			end
		when 4
			# 4 vectors
			if args.all?{|x| x.is_a? GLM::Vec4 }
				return super(*args)
				# return self
			end
		end
		
		# should have returned successfully by now
		raise "ERROR: unrecognized arguments given to GLM::Mat4.new. Expected either 1 scalar (float) or 4 vectors (Vec4) but recieved #{args.inspect}"
		
		
	end
end

end
