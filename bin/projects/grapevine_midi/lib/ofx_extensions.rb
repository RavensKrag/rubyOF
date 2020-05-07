module RubyOf
	module OFX


class MidiOut
	def openPort(port_num_or_name)
		case port_num_or_name
			when Integer
				self.openPort_uint(port_num_or_name)
			when String
				self.openPort_string(port_num_or_name)
			else 
				raise ArgumentError, "Expected Integer or String but recieved #{port_num_or_name.class}"
		end
	end
end
	

end
end
