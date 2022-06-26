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


class TestContainer
	attr_accessor :str
	
	def initialize
		@str = "???"
	end
end

def main()
	buf = RingBuffer.new(10, TestContainer)
	
	(1..20).each do |i|
		puts i
		buf[i].str = i.to_s
		
		p buf
		p buf.to_a.map{ |x| x.str }
		puts ""
	end
	
	i = 15
	puts i
	buf[i].str = "hello world"
	
	p buf
	p buf.to_a.map{ |x| x.str }
	puts ""
	
	
	# require 'irb'
	# binding.irb
end



main()
