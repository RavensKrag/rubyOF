# encoding: UTF-8
this_dir     = File.absolute_path(File.dirname(__FILE__))
project_root = File.expand_path('../',          this_dir)
gem_root     = File.expand_path('../../../../', this_dir)



puts "this_dir     = #{this_dir}"
puts "project_root = #{project_root}"
puts "gem_root     = #{gem_root}"


require File.expand_path('lib/rubyOF', gem_root)


require File.expand_path('lib/window', project_root)


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
	[
		:initialize,
		:setup,
		:update,
		:draw,
		:on_exit,
		:key_pressed,
		:key_released,
		:mouse_moved,
		:mouse_pressed,
		:mouse_released,
		:mouse_dragged
	].each do |method|
		define_method method do |*args|
			exception_guard do
				super(*args)
			end
		end
	end
end

x = WindowGuard.new # initialize
x.show              # start up the c++ controled infinite render loop

# display any uncaught ruby-level exceptions after safely exiting C++ code
unless x.exception.nil?
	raise x.exception
end
