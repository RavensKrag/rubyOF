require 'pathname'

current_file = Pathname.new(__FILE__).expand_path
current_dir = current_file.parent
LIB_DIR = current_dir.parent


require 'forwardable' # for def_delegators

require 'json' # easiest way to transfer data between Python and Ruby
require 'base64'

require 'open3'

require 'io/wait'

load LIB_DIR/'ring_buffer.rb'




def main()
	buf = RingBuffer.new(10)
	
	100.times do |i|
		if i != 0
			buf.push i
		end
		
		p buf
		p buf.to_a
		puts ""
	end
	
	# require 'irb'
	# binding.irb
end



main()
