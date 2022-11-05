# NOTE: This file must be included after a custom Window class is defined.

# Wrap the window class in some exception handling code
# to make up for things that I don't know how to handle with Rice.
class ExceptionGuard
	attr_reader :exception
	
	def initialize(&block)
		@window = block.call
		
		
		# wrap each and every callback method in an exception guard
		# (also wrap initialize too, because why not)
		methods = (@window.class.instance_methods - Object.instance_methods) +
		          [:initialize]
		
		methods.each do |method|
			meta_def method do |*args|
				guard do
					@window.send(method, *args)
				end
			end
		end
	end
	
	private
	
	def guard() # &block
		begin
			yield
		rescue => e
			@exception ||= e
			# puts e
			# ^ storing first exeception in chain can make errors easier to read
			puts "=> exception caught"
			RubyOF::Utils.ofExit()
			# ^ needs to be able to call this here
			#   where is exit defined now?
		end
	end
end
