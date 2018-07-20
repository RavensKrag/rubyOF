class AbstractionHelper1
	def initialize(&block)
		@block = block
	end
	
	def gate
		# busy-wait until invariant specified by @block is satisfied
		puts "waiting for variable to be set..."
		until @block.call do
			# NO-OP
			p @block.call
			puts "waiting... "
		end
		puts "variable found!"
	end
end

class AbstractionHelper2
	def initialize(&block)
		@block = block
	end
	
	def gate
		# busy-wait until invariant specified by @block is satisfied
		puts "waiting for variable to be set..."
		until @block.call != nil do
			# NO-OP
			p @block.call
			puts "waiting... "
		end
		puts "variable found!"
	end
end

class AbstractionHelper3
	def initialize(&block)
		@block = block
	end
	
	def gate
		# busy-wait until invariant specified by @block is satisfied
		puts "waiting for variable to be set..."
		until @block.call.all?{|x| x != nil } do
			# NO-OP
			p @block.call
			puts "waiting... "
		end
		puts "variable found!"
	end
end


class Context
	def initialize
		# -- use defined? to see if variable is set
		#    WORKS!
		# @c1 = AbstractionHelper1.new do
		# 	defined? @x
		# end
		
		# -- assume non-nil indicates a set value
		#    WORKS!
		# @c1 = AbstractionHelper2.new{ @x }
		
		# -- try to check for multiple variables
		#    WORKS! Ruby's late binding works here too!
		@c1 = AbstractionHelper3.new{ [@x, @y, @z] }
	end
	
	def run
		# --- uncomment this, and the invariant succeeds, as expected
		# @x = 1                   # case 1, 2
		@x = 1; @y = 2; @z = 3   # case 3
		
		
		@c1.gate
	end
end





Context.new.run
