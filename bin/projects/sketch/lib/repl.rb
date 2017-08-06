require 'irb'

REPL = Object.new
def REPL.connect(binding, blocking:false)
	Thread.kill(@irb_thread) unless @irb_thread.nil?
	
	@irb_thread = Thread.new do
		binding.irb
		
		# Can I redirect the STDIN and STDOUT streams of this thread somewhere else?
		# I'd ideally like to be able to access this from a different terminal session.
		
		# (Alternatively, pipe the main thread's output somewhere else? Like a file, and then stream that file to another terminal.)
	end
	
	@irb_thread.join if blocking
end

def REPL.disconnect
	Thread.kill(@irb_thread) unless @irb_thread.nil?
end

