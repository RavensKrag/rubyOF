class FiberQueue
	attr_reader :state
	
	def initialize(&block)
		@state = :idle # :idle, :active, :finished
		
		@fiber = Fiber.new do |*inital_args|
			block.call(*inital_args)
			
			Fiber.yield(:finished)
		end
	end
	
	def resume(*args)
		unless @fiber.nil?
			@state = :active
			# p @fiber
			# p @fiber.methods
			out = @fiber.resume(*args)
			# @fiber.resume
			
			if out == :finished
				@state = :finished
				# this output is not a generated value
				# but a signal that we can't generate anything else
				puts "#{self.class}: No more work to be done in this Fiber."
				@fiber = nil
				return nil
			else
				# process the generated value
				return out
			end
		end
	end
	
	def transfer(*args)
		unless @fiber.nil?
			@state = :active
			# p @fiber
			# p @fiber.methods
			out = @fiber.transfer(*args)
			# @fiber.transfer
			
			if out == :finished
				@state = :finished
				# this output is not a generated value
				# but a signal that we can't generate anything else
				puts "#{self.class}: No more work to be done in this Fiber."
				@fiber = nil
				return nil
			else
				# process the generated value
				return out
			end
		end
	end
end
