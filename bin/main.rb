# Helper function for starting up any of Ruby-level project
# 
# Assumes GEM_ROOT has already been defined
# GEM_ROOT is defined in (project_root/'config'/'build_variables')
def main(project_root)
	require (GEM_ROOT/'build'/'extension_loader')
	# ^ defines the function 'load_c_extension_lib'
	
	
	# TODO: overhaul the way constants are defined and loaded. I don't want to have to redefine the install paths in this file, or the 'rubyOF' name.
	
	root = Pathname.new(GEM_ROOT)
	
	name = 'rubyOF'
	
	
	core_install_location    = root/'lib'/name/"#{name}.so"
	
	project_install_location = project_root/'bin'/'lib'/"#{name}_project.so"
	
	puts "Loading c-extension for core..."
	load_c_extension_lib core_install_location
	
	puts "Loading c-extension for project..."
	load_c_extension_lib project_install_location
	
	
	
	
	puts "loading Ruby dependencies using Bundler..."
	# NOTE: The baseline Ruby code for RubyOF declares some dependencies through bundler. Those will be loaded in this step, as well as the dependencies for this particular project.
	require 'bundler/setup'
	Bundler.require
	
	puts "Load Ruby code that defines RubyOF..."
	require (GEM_ROOT / 'lib' / 'rubyOF')
	
	puts "Load up the project-specific Ruby code for the window..."
	require (project_root/'lib'/'app')
	
	
	# Load WindowGuard class definition (extends custom Window class)
	require (GEM_ROOT / 'build' / 'window_guard')
	
	
	
	# === Main
	
	# initialize
	rb_app = WindowGuard.new do
		yield # initialize RbApp in project main (ruby-only class)
	end
	# TODO: rename WindowGuard to something more generic
	
	
	unless rb_app.exception
		# start up the c++ controled infinite render loop
		# unless there was an execption thrown during initialization
		RubyOF::Launcher.run(rb_app) # binds ofWindow and ofApp to rb_app
	end
	
	
	# display any uncaught ruby-level exceptions after safely exiting C++ code
	unless rb_app.exception.nil?
		puts "[GEM_ROOT]/bin/main.rb: Uncaught exeception"
		# raise rb_app.exception
		msg = rb_app.exception.full_message
				.gsub!(GEM_ROOT.to_s, "[GEM_ROOT]")
	
		puts msg
	end
end
