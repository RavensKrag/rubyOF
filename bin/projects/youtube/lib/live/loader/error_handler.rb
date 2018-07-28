module LiveCoding

module ErrorHandler
	# error handling helper
	def print_wrapped_error(e)
		# process_runtime_error(package, e)
		puts "KABOOM!"
		
		# everything below this point deals only with the execption object 'e'
		
		
		# FACT: Proc with instance_eval makes the resoultion of e.message very slow (20 s)
		# FACT: Using class-based snippets makes resolution of e.message quite fast (10 ms)
		# ASSUME: Proc takes longer to resolve because it has to look in the symbol table of another object (the Window)
		# --------------
		# CONCLUSION: Much better for performance to use class-based snippets.
		
		Thread.new do
			# NOTE: Can only call a fiber within the same thread.
			
			t1 = RubyOF::Utils.ofGetElapsedTimeMillis
			
			out = [
				# e.class, # using this instead of "message"
				# e.name, # for NameError
				# e.local_variables.inspect,
				# e.receiver, # this might actually be the slow bit?
				e.message, # message is the "rate limiting step"
				e.backtrace
			]
			
			# p out
			puts out.join("\n")
			
			
			t3 = RubyOF::Utils.ofGetElapsedTimeMillis
			dt = t3 - t1
			puts "Final dt: #{dt} ms"
			puts ""
		end
	end
end

end
