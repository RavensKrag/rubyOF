# NOTE: This file must be included after a custom Window class is defined.

# Wrap the window class in some exception handling code
# to make up for things that I don't know how to handle with Rice.
class WindowGuard < Window
	attr_reader :exception
	
	private
	
	def exception_guard() # &block
		begin
			yield
		rescue => e
			@exception = e
			puts "=> exception caught"
			ofExit()
		end
	end
	
	public
	
	# wrap each and every callback method in an exception guard
	# (also wrap initialize too, because why not)
	
	# [
	# 	:initialize,
	# 	:setup,
	# 	:update,
	# 	:draw,
	# 	:on_exit,
	# 	:key_pressed,
	# 	:key_released,
	# 	:mouse_moved,
	# 	:mouse_pressed,
	# 	:mouse_released,
	# 	:mouse_dragged
	# ]
	methods = (Window.instance_methods - Object.instance_methods) +
	          [:initialize]
	methods.each do |method|
		define_method method do |*args|
			exception_guard do
				super(*args)
			end
		end
	end
end
