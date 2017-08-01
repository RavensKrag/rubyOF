# encoding: UTF-8
this_dir     = File.absolute_path(File.dirname(__FILE__))
project_root = File.expand_path('../',          this_dir)
gem_root     = File.expand_path('../../../../', this_dir)



puts "this_dir     = #{this_dir}"
puts "project_root = #{project_root}"
puts "gem_root     = #{gem_root}"


require File.expand_path('lib/rubyOF', gem_root)


puts "load project-specific C++ code..."

# Stolen from Gosu's code to load the dynamic library
# TODO: check this code, both here and in the main build, when you actually try building for Windows. Is it neccessary? Does it actually work? It's rather unclear. (I don't think I'm defining RUBY_PLATFORM anywhere, so may have to at least fix that.)
if defined? RUBY_PLATFORM and
%w(-win32 win32- mswin mingw32).any? { |s| RUBY_PLATFORM.include? s } then
	ENV['PATH'] = "#{File.dirname(__FILE__)};#{ENV['PATH']}"
end

# separate C extension for project-specific bindings
# (things that are not part of OpenFrameworks core)
[
	'ext/callbacks/rubyOF_project',
].each do |path|
	require File.expand_path(path, project_root)
end


# Load up the project-specific Ruby code for the window
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
