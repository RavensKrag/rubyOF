# encoding: UTF-8

require 'pathname'

project_root = Pathname.new(__FILE__).expand_path.dirname.parent
puts "project_root = #{project_root}"

require (project_root/'config'/'build_variables')
# ^ defines the GEM_ROOT constant

require (Pathname.new(GEM_ROOT)/'build'/'extension_loader')
# ^ defines the function 'load_c_extension_lib'



puts "Load project-specific C++ code..."
load_c_extension_lib (project_root/'ext'/'callbacks'/'rubyOF_project')

puts "Load final dynamic library (Rice wrapper and project code)..."
load_c_extension_lib (project_root/'bin'/'lib'/'rubyOF')

puts "loading Ruby dependencies using Bundler..."
# NOTE: The baseline Ruby code for RubyOF declares some dependencies through bundler. Those will be loaded in this step, as well as the dependencies for this particular project.
require 'bundler/setup'
Bundler.require

puts "Load Ruby code that defines RubyOF..."
require (Pathname.new(GEM_ROOT) / 'lib' / 'rubyOF')

puts "Load up the project-specific Ruby code for the window..."
require (project_root/'lib'/'window')


# Load WindowGuard class definition (extends custom Window class)
require (Pathname.new(GEM_ROOT) / 'build' / 'window_guard')



# === Main
x = WindowGuard.new # initialize
x.show              # start up the c++ controled infinite render loop

# display any uncaught ruby-level exceptions after safely exiting C++ code
unless x.exception.nil?
	raise x.exception
end
