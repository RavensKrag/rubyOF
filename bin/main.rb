# Helper function for starting up any of Ruby-level project
def main(project_root)
	puts "Load project-specific C++ code..."
	load_c_extension_lib (project_root/'ext'/'callbacks'/'rubyOF_project')
	
	puts "Load final dynamic library (Rice wrapper and project code)..."
	load_c_extension_lib (project_root/'bin'/'lib'/'rubyOF')
	
	puts "loading Ruby dependencies using Bundler..."
	# NOTE: The baseline Ruby code for RubyOF declares some dependencies through bundler. Those will be loaded in this step, as well as the dependencies for this particular project.
	require 'bundler/setup'
	Bundler.require
	
	puts "Load Ruby code that defines RubyOF..."
	require (GEM_ROOT / 'lib' / 'rubyOF')
	
	puts "Load up the project-specific Ruby code for the window..."
	require (project_root/'lib'/'window')
	
	
	# Load WindowGuard class definition (extends custom Window class)
	require (GEM_ROOT / 'build' / 'window_guard')
	
	
	
	# === Main
	x = WindowGuard.new # initialize

	# start up the c++ controled infinite render loop
	# unless there was an execption thrown during initialization
	x.show unless x.exception
	
	# display any uncaught ruby-level exceptions after safely exiting C++ code
	unless x.exception.nil?
		raise x.exception
	end
end
