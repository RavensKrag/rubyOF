module CP


class Body
	def to_yaml_type
		"!ruby/object:#{self.class}"
	end

	def encode_with(coder)
		symbols = [
			'p', 'v', 'f', 'v_limit',
			'a', 'w', 't', 'w_limit',
			'm', 'i'
		]
		data = symbols.collect{ |x| self.send x }
		
		coder.represent_map to_yaml_type, symbols.zip(data).to_h
		
		# :pos, :pos=, :activate, :t=, :f, :rot, :m=, :i=, :p=, :v=, :f=, :a=, :a, :w=, :moment, :vel, :ang_vel, :torque, :m_inv, :mass_inv, :moment_inv, :v_limit, :w_limit, :mass=, :moment=, :vel=, :force=, :angle=, :ang_vel=, :torque=, :i, :w_limit=, 
	end

	def init_with(coder)
		x = coder.map['m']
		y = coder.map['i']
		initialize(coder.map['m'], coder.map['i'])
		
		# Kernel.p coder.map
		# Kernel.p coder.map["p"]
		
		symbols = [
			'p', 'v', 'f', 'v_limit',
			'a', 'w', 't', 'w_limit'
		].each do |msg|
			self.send "#{msg}=", coder.map[msg]
		end
	end
end



end
