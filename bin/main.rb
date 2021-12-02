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
	
	project_name = ENV['RUBYOF_PROJECT']
	project_dir  = root/'bin'/'projects'/project_name
	project_install_location = project_dir/'bin'/'lib'/"#{name}_project.so"
	
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
		puts "[GEM_ROOT]/bin/main.rb: Uncaught exeception"
		raise x.exception
	end
end
