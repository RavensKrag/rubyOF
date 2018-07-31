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
			
			# out = [
			# 	# e.class, # using this instead of "message"
			# 	# e.name, # for NameError
			# 	# e.local_variables.inspect,
			# 	# e.receiver, # this might actually be the slow bit?
			# 	e.message, # message is the "rate limiting step"
			# 	e.backtrace
			# ]
			
			# p e
			
			puts e.full_message
			# ^ use ruby internal code to format the message. implementation is in c for speed. this will format exactly the same as a normal exception, which in ruby 2.5 includes bolding and other font styles.
			# sources:
				# line 224, see the implementation in C
				# https://github.com/ruby/ruby/blob/aa2b32ae4bac4e1fcfc5986977d9111b32d0458e/eval_error.c
				
				# search for "traceback" to see the tests, and usage Ruby-side
				# https://github.com/ruby/ruby/blob/d459572c10d4f8a63a659278266facaf99293267/test/ruby/test_exception.rb
				
			
			# puts out.join("\n")
			
			
			t3 = RubyOF::Utils.ofGetElapsedTimeMillis
			dt = t3 - t1
			puts "Final dt: #{dt} ms"
			puts ""
		end
	end
end

end
