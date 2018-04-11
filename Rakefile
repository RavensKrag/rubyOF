require 'rake/testtask'
require 'rake/clean'

require 'fileutils'
require 'open3'
require 'yaml' # used for config files
require 'json' # used to parse Clang DB


require './common'
# ^ this file declares GEM_ROOT constant, other constants, and a some functions

load './rake/helper_functions.rb'
load './rake/clean_and_clobber.rb'



# ==== rake argument documentation ====
# :rubyOF_project		name of project (if under project directory)
#                         OR
#                    full path to project (if stored elsewhere)
# =====================================



# generate depend file for gcc dependencies
# sh "gcc -MM *.c > depend"

load './rake/oF_core.rake'
load './rake/oF_deps.rake'
# load './rake/oF_project.rake'
# load './rake/extension.rake'


# defines RubyOF::Build.create_project and RubyOF::Build.load_project
require File.join(GEM_ROOT, 'build', 'build.rb')



def build_c_extension(c_extension_dir)
	Dir.chdir(c_extension_dir) do
		# this does essentially the same thing
		# as what RubyGems does
		puts "=> starting extconf..."
		
		begin
			run_i "ruby extconf.rb"
		rescue StandardError => e
			puts "ERROR: Could not configure c extension."
			exit
		end
		
		puts "=> configuration complete. building C extension"
		
		
		flags = ""
		# flags += " -j#{NUMBER_OF_CORES}" if Dir.exists? '/home/ravenskrag' # if running on my machine
		
		puts "Building..."
		begin
			run_i "make #{flags}"
		rescue StandardError => e
			puts "ERROR: Could not build c extension."
			exit
		end
	end
	
	# # NOTE: This is part of a normal extconf build, but I don't want it.
	# #       In the context of this build, this .so is only an intermediate.
	# # puts "=== Moving dynamic library into correct location..."
	# FileUtils.cp "ext/#{NAME}/#{NAME}.so", "lib/#{NAME}"
	
	
	puts "=> C extension build complete!"
end

def parse_build_variable_data(data)
	data.select{  |line|
		line.include? '='
	}.collect{   |line|
		# can't just split on '='
		# because there can be mulitple equal signs
		# 
		# The thing before the FIRST equal sign is the key,
		# everything else on the line is the value associated with the key
		i = line.index("=")
		key   = line[0..(i-1)]
		value = line[((i+1)..-1)]
		
		
		key, value = [key, value].collect{ |x| x.strip }
		
		value = value.split()
		
		
		[key, value]
	}.to_h
end


# 1) build testApp using oF build system
# 2) export build vars from testApp
# 3) reverse engineer build vars for use in ruby's extconf.rb system
# 4) use extconf.rb and Rice to build dynamic library of wrapper for *core oF* functionality
# 5) move dynamic library into easy-to-load location
namespace :core_wrapper do
	c_extension_dir = Pathname.new(GEM_ROOT)/"ext"/NAME
	c_extension_file = c_extension_dir/"#{NAME}.so"
	
	install_location = "lib/#{NAME}/#{NAME}.so"
	
	
	# NOTE: This only works for linux, because it explicitly uses the ".so" extension
	
	# TODO: update source file list
	extension_dependencies = Array.new.tap do |deps|
		# Ruby / Rice CPP files
		deps.concat Dir.glob("ext/#{NAME}/**/*{.cpp,.h}")
		
		# 
		deps << "ext/#{NAME}/extconf.rb"
		deps << "ext/#{NAME}/extconf_common.rb"
		deps << "ext/#{NAME}/extconf_printer.rb"
		
		deps << __FILE__ # depends on this Rakefile
		
		# deps << OF_BUILD_VARIABLE_FILE
		# TODO: ^ re-enable this ASAP
		
		# NOTE: adding OF_BUILD_VARIABLE_FILE to the dependencies for the 'c_extension_file' makes it so extconf.rb has to run every time, because the variable file is being regenerated every time.
		
		# deps.concat Dir.glob("ext/#{NAME}/*{.rb,.c}")
	end
	
	# TODO: figure out where to clean up c_extension_file
	#       is that in clean? clobber? something else? not sure
	#       should there be install/uninstall tasks too?
	
	task :clean do
		Dir.chdir OF_SKETCH_ROOT do
			begin
				run_i "make clean"
			rescue StandardError => e
				puts "ERROR: Unknown problem while cleaning #{OF_SKETCH_NAME}."
				exit
			end
			# FileUtils.touch 'oF_project_build_timestamp'
		end
		
		Dir.chdir c_extension_dir do
			begin
				run_i "make clean"
			rescue StandardError => e
				puts "ERROR: Unknown problem while cleaning C extension dir for core wrapper."
				exit
			end
		end
	end
	
	task :clobber => :clean do
		FileUtils.rm install_location
	end
	
	task :build => [
		:build_app,		         # build testApp using oF build system
		OF_BUILD_VARIABLE_FILE, # export build vars -> reformat
		c_extension_file,       # build wrapper
		:move_dynamic_lib       # move dynamic library into easy-to-load location
	]
	
	
	# 1) build testApp using oF build system
	task :build_app do
		puts "=== Building #{OF_SKETCH_NAME}..."
		Dir.chdir OF_SKETCH_ROOT do
			# Make the debug build if the flag is set,
			# othwise, make the release build.
			debug = OF_DEBUG ? "Debug" : ""
			
			
			begin
				run_i "make #{debug} -j#{NUMBER_OF_CORES}"
			rescue StandardError => e
				puts "ERROR: Could not build #{OF_SKETCH_NAME}."
				exit
			end
			# FileUtils.touch 'oF_project_build_timestamp'
		end
	end
	
	# 2) export build vars from testApp
	file OF_RAW_BUILD_VARIABLE_FILE => [
		Pathname.new(OF_SKETCH_ROOT)/'Makefile.static_lib',
		__FILE__,     # if the Rake task changes, then update the output file
		COMMON_CONFIG # if config variables change, then build may be different
	] do
		puts "=== Exporting oF project build variables..."
		
		Dir.chdir OF_SKETCH_ROOT do
			swap_makefile(OF_SKETCH_ROOT, "Makefile", "Makefile.static_lib") do
				# run_i "make printvars"
				
				out = `make printvars TARGET_NAME=#{TARGET}`
				# p out
				
				out = out.each_line.to_a
				
				
				File.open(OF_RAW_BUILD_VARIABLE_FILE, "w") do |f|
					f.puts out.to_yaml
				end
			end
		end
	end
	
	# 3) reverse engineer build vars for use in ruby's extconf.rb system
	file OF_BUILD_VARIABLE_FILE => OF_RAW_BUILD_VARIABLE_FILE do
		puts "=== reformatting..."
		Dir.chdir OF_SKETCH_ROOT do
			data = YAML.load_file(OF_RAW_BUILD_VARIABLE_FILE)
			
			final = parse_build_variable_data(data)
			
			filepath = OF_BUILD_VARIABLE_FILE
			File.open(filepath, "w") do |f|
				f.puts final.to_yaml
			end
			
			puts "=> Variables written to '#{filepath}'"
			puts ""
		end
	end
	
	
	# 4) use extconf.rb and Rice to build dynamic library of wrapper for core oF functionality
	
	# Mimic RubyGems gem install procedure, for testing purposes.
	# * run extconf
	# * execute the resultant makefile
	# * move the .so to it's correct location
	file c_extension_file => extension_dependencies do
		puts "=== building core wrapper..."
		build_c_extension(c_extension_dir)
	end
	
	
	# 5) move dynamic library into easy-to-load location]
	task :move_dynamic_lib do
		puts "=== moving dynamic lib to easy-to-load location"
		FileUtils.cp c_extension_file, install_location
		puts "=> DONE!"
	end
end



# arguments:   [project_name]

# Projects use some combination of Ruby and C++ to build on the framework,
# and accomplish a specific goal.

# 1) take in exported and reformatted vars from the core wrapper
# 2.1) build a whole dummy app, just to to build addons
# 2.2) export build vars from dummy app
# 2.3) reverse engineer build vars for use in ruby's extconf.rb system
# 2.4) extract just the addons info from the build var data
# 3) take core variables, and mix in information needed for addons
# 4) load new mixed build variables into extconf.rb and create makefile
# 5) run makefile, and create dynamic library for project-level code
# 6) move dynamic library into easy-to-load location

namespace :project_wrapper do
	root = Pathname.new(GEM_ROOT)
	
	project_name = 'youtube'
	project_dir  = root/'bin'/'projects'/project_name
	
	
	addons_app_dir = project_dir/'ext'/'new'/'addons_app'/'testApp'
	raw_build_variable_file = addons_app_dir/'raw_oF_variables.yaml'
	build_variable_file     = addons_app_dir/'oF_build_variables.yaml'
	addons_data             = addons_app_dir/'addons.yaml'
	
	mixed_build_variable_file = addons_app_dir/'mixed_build_variables.yaml'
	
	
	c_extension_dir = root/"ext"/NAME
	c_extension_file = c_extension_dir/"#{NAME}.so"
	
	# NOTE: This only works for linux, because it explicitly uses the ".so" extension
	
	# TODO: update source file list
	extension_dependencies = Array.new.tap do |deps|
		# Ruby / Rice CPP files
		deps.concat Dir.glob("ext/#{NAME}/**/*{.cpp,.h}")
		
		# 
		deps << mixed_build_variable_file
		
		deps << "ext/#{NAME}/extconf.rb"
		deps << "ext/#{NAME}/extconf_common.rb"
		deps << "ext/#{NAME}/extconf_printer.rb"
		
		deps << __FILE__ # depends on this Rakefile
		
		# deps << OF_BUILD_VARIABLE_FILE
		# TODO: ^ re-enable this ASAP
		
		# NOTE: adding OF_BUILD_VARIABLE_FILE to the dependencies for the 'c_extension_file' makes it so extconf.rb has to run every time, because the variable file is being regenerated every time.
		
		# deps.concat Dir.glob("ext/#{NAME}/*{.rb,.c}")
	end
	
	task :clean do
		Dir.chdir addons_app_dir do
			begin
				run_i "make clean"
			rescue StandardError => e
				puts "ERROR: Unknown problem while cleaning app for project #{project_name}."
				exit
			end
			# FileUtils.touch 'oF_project_build_timestamp'
		end
		
		# Dir.chdir c_extension_dir do
		# 	begin
		# 		run_i "make clean"
		# 	rescue StandardError => e
		# 		puts "ERROR: Unknown problem while cleaning C extension dir for core wrapper."
		# 		exit
		# 	end
		# end
	end
	
	task :clobber => :clean do
		
	end
	
	task :build => [
		:build_addons_app,
		
		# raw_build_variable_file -> build_variable_file -> addons_data
		addons_data
	]
	
	
	
	# 2.1) build a whole dummy app, just to to build addons
	task :build_addons_app do 
		puts "=== Building project '#{project_name}'..."
		Dir.chdir addons_app_dir do
			# Make the debug build if the flag is set,
			# othwise, make the release build.
			debug = OF_DEBUG ? "Debug" : ""
			
			
			begin
				run_i "make #{debug} -j#{NUMBER_OF_CORES}"
			rescue StandardError => e
				puts "ERROR: Could not build project '#{project_name}'"
				exit
			end
			# FileUtils.touch 'oF_project_build_timestamp'
		end
	end
	
	# 2.2) export build vars from dummy app
	file raw_build_variable_file => [
		addons_app_dir/'Makefile.static_lib',
		__FILE__,     # if the Rake task changes, then update the output file
		COMMON_CONFIG # if config variables change, then build may be different
	] do
		puts "=== Exporting oF project build variables..."
		
		Dir.chdir addons_app_dir do
			swap_makefile(addons_app_dir, "Makefile", "Makefile.static_lib") do
				# run_i "make printvars"
				
				out = `make printvars TARGET_NAME=#{TARGET}`
				# p out
				
				out = out.each_line.to_a
				
				
				File.open(raw_build_variable_file, "w") do |f|
					f.puts out.to_yaml
				end
			end
		end
	end
	
	# 2.3) reverse engineer build vars for use in ruby's extconf.rb system
	file build_variable_file => raw_build_variable_file do
		puts "=== reformatting..."
		Dir.chdir addons_app_dir do
			data = YAML.load_file(raw_build_variable_file)
			
			final = parse_build_variable_data(data)
			
			filepath = build_variable_file
			File.open(filepath, "w") do |f|
				f.puts final.to_yaml
			end
			
			puts "=> Variables written to '#{filepath}'"
			puts ""
		end
	end
	
	
	# 2.4) extract just the addons info from the build var data
	file addons_data => build_variable_file do
		puts "== extracting addon data..."
		
		Dir.chdir addons_app_dir do
			data = YAML.load_file(build_variable_file)
			data['OF_PROJECT_ADDONS_OBJS']
			
			
			keys = %w[
				ALL_INSTALLED_ADDONS
				VALID_PROJECT_ADDONS
				PROJECT_ADDONS
				OF_PROJECT_ADDONS_OBJS
				PROJECT_ADDONS_CFLAGS
				PROJECT_ADDONS_DATA
				PROJECT_ADDONS_FRAMEWORKS
				PROJECT_ADDONS_INCLUDES
				PROJECT_ADDONS_LDFLAGS
				PROJECT_ADDONS_LIBS
			]
			final = 
				data.select {  |k,v|
					keys.include? k
				}
			
			
			filepath = addons_data
			File.open(filepath, "w") do |f|
				f.puts final.to_yaml
			end
			
			puts "=> Variables written to '#{filepath}'"
			puts ""
		end
			# OF_PROJECT_ADDONS_OBJS
			# PROJECT_ADDONS
			# PROJECT_ADDONS_SOURCE_FILES
			# PARSED_ADDONS_FILTERED_LIBS_SOURCE_INCLUDE_PATHS
			# addon
			# PROJECT_ADDONS_LDFLAGS
			# PLATFORM_REQUIRED_ADDONS
			# PARSED_ADDONS_LIBS_SOURCE_INCLUDES
			# B_PROCESS_ADDONS: 'yes'
			# PARSED_ADDONS_LIBS_SOURCES
			# PARSED_ADDONS_FILTERED_INCLUDE_PATHS
			# ADDONS_INCLUDES_FILTER
			# TMP_PROJECT_ADDONS_PKG_CONFIG_LIBRARIES
			# PROJECT_ADDONS_OBJ_FILES
			# PROJECT_ADDONS_FRAMEWORKS
			# PARSED_ADDONS_LIBS_PLATFORM_LIB_PATHS
			# PARSED_ADDONS_SOURCE_INCLUDES
			# INVALID_PROJECT_ADDONS
			# INVALID_GLOBAL_ADDONS
			# TMP_PROJECT_ADDONS_SOURCE_FILES
			# PARSED_ADDONS_SOURCE_PATHS
			# TMP_PROJECT_ADDONS_OBJ_FILES
			# VALID_PROJECT_ADDONS
			# PARSED_ADDONS_LIBS_SOURCE_PATHS
			# PARSED_ADDONS_SOURCE_FILES
			# TMP_PROJECT_ADDONS_LDFLAGS
			# ADDONS_SOURCES_FILTER
			# TMP_PROJECT_ADDONS_FRAMEWORKS
			# PARSED_ADDONS_LIBS_INCLUDES_PATHS
			# PROJECT_ADDONS_INCLUDES
			# PARSED_ADDONS_FILTERED_LIBS_SOURCE_PATHS
			# REQUESTED_PROJECT_ADDONS
			# PROJECT_ADDONS_OBJ_PATH
			# OF_PROJECT_ADDONS_DEPS
			# parse_addons_sources
			# parse_addons_libraries
			# parse_addons_includes
			# TMP_PROJECT_ADDONS_INCLUDES
			# PARSED_ADDONS_FILTERED_LIBS_INCLUDE_PATHS
			# ADDON_INCLUDE_CFLAGS
			# PARSED_ADDONS_INCLUDES
			# PROJECT_ADDONS_CFLAGS
			# PARSED_ADDONS_OFX_SOURCES
			# PROJECT_ADDONS_DATA
			# PARSED_ADDONS_LIBS_INCLUDES
			# ADDON_LIBS
			# PROJECT_ADDONS_LIBS
			# ALL_INSTALLED_ADDONS
			
			# -------------------------
			# raw data above, organized data below
			
			
			
			# B_PROCESS_ADDONS: 'yes'
			
			# ALL_INSTALLED_ADDONS
			# INVALID_GLOBAL_ADDONS
			# INVALID_PROJECT_ADDONS
			# VALID_PROJECT_ADDONS
			# PLATFORM_REQUIRED_ADDONS
			
			# addon
			# ADDON_INCLUDE_CFLAGS
			# ADDON_LIBS
			# ADDONS_INCLUDES_FILTER
			# ADDONS_SOURCES_FILTER
			# OF_PROJECT_ADDONS_DEPS
			# OF_PROJECT_ADDONS_OBJS
			
			# PROJECT_ADDONS
			# PROJECT_ADDONS_CFLAGS
			# PROJECT_ADDONS_DATA
			# PROJECT_ADDONS_FRAMEWORKS
			# PROJECT_ADDONS_INCLUDES
			# PROJECT_ADDONS_LDFLAGS
			# PROJECT_ADDONS_LIBS
			# PROJECT_ADDONS_OBJ_FILES
			# PROJECT_ADDONS_OBJ_PATH
			# REQUESTED_PROJECT_ADDONS
			# PROJECT_ADDONS_SOURCE_FILES
			
			
			# PARSED_ADDONS_FILTERED_INCLUDE_PATHS
			# PARSED_ADDONS_FILTERED_LIBS_INCLUDE_PATHS
			# PARSED_ADDONS_FILTERED_LIBS_SOURCE_INCLUDE_PATHS
			# PARSED_ADDONS_FILTERED_LIBS_SOURCE_PATHS
			# PARSED_ADDONS_INCLUDES
			# PARSED_ADDONS_LIBS_INCLUDES
			# PARSED_ADDONS_LIBS_INCLUDES_PATHS
			# PARSED_ADDONS_LIBS_PLATFORM_LIB_PATHS
			# PARSED_ADDONS_LIBS_SOURCE_INCLUDES
			# PARSED_ADDONS_LIBS_SOURCE_PATHS
			# PARSED_ADDONS_LIBS_SOURCES
			# PARSED_ADDONS_OFX_SOURCES
			# PARSED_ADDONS_SOURCE_FILES
			# PARSED_ADDONS_SOURCE_INCLUDES
			# PARSED_ADDONS_SOURCE_PATHS
			
			
			# TMP_PROJECT_ADDONS_FRAMEWORKS
			# TMP_PROJECT_ADDONS_INCLUDES
			# TMP_PROJECT_ADDONS_LDFLAGS
			# TMP_PROJECT_ADDONS_OBJ_FILES
			# TMP_PROJECT_ADDONS_PKG_CONFIG_LIBRARIES
			# TMP_PROJECT_ADDONS_SOURCE_FILES
	end
	
	# 3) take core variables, and mix in information needed for addons
	file mixed_build_variable_file => addons_data do
		
	end
	
	
	
	# TODO: update extension file path
	# TODO: update extension dependencies
	# TODO: move conserved code in this extension bulid and the one above in to a single function that is called in both places
	
	# 4) load new mixed build variables into extconf.rb and create makefile
	# Mimic RubyGems gem install procedure, for testing purposes.
	# * run extconf
	# * execute the resultant makefile
	# * move the .so to it's correct location
	file c_extension_file => extension_dependencies do
		puts "=== building core wrapper..."
		build_c_extension(c_extension_dir)
	end
end

# Put everything together
# + load dynamic library for core wrapper
# + load dynamic library for a particular project
# + require Ruby code for that same project
# + open and run the Window associated with that project
namespace :execution do
	
end









# load the RubyOF::Build::ExtensionBuilder definition
load './rake/extension_builder.rb'

namespace :cpp_project do
	
	task :build, [:rubyOF_project] do |t, args|
		puts "=== Buliding cpp project ==="
		obj = RubyOF::Build::ExtensionBuilder.new(args[:rubyOF_project])
		obj.main
	end	
	
	task :clean, [:rubyOF_project] do |t, args|
		obj = RubyOF::Build::ExtensionBuilder.new(args[:rubyOF_project])
		obj.clean
	end
	
	task :clobber, [:rubyOF_project] => :clean do |t, args|
		obj = RubyOF::Build::ExtensionBuilder.new(args[:rubyOF_project])
		obj.clobber
	end
	
	
	task :build_addons_lib do |t, args|
		puts "--- building addons"
		
		# You can run a different Makefile than the default
		# 
		# src: https://stackoverflow.com/questions/12057852/multiple-makefiles-in-one-directory
		
		name_or_path = args[:rubyOF_project]
		name, path = RubyOF::Build.load_project(name_or_path)
		
		project_root = Pathname.new(path)
		work_dir     = project_root/'ext'/'addons_app'/'testApp'
		Dir.chdir work_dir do
			puts "> in working dir"
			
			puts "> building dummy project (and also the addons)"
			run_i "make -f Makefile -j#{NUMBER_OF_CORES}"
			
			puts "> collect addon libs into single archive (.a file)"
			run_i "make -f Makefile.static_lib -j#{NUMBER_OF_CORES} static_lib"
			
			puts "> make sure the symbols are actually in there"
			run_i "nm -C ./lib/libOF_ProjectAddons.a"
			
			puts "SUCCESS!!! addons lib built"
		end
	end
	
end





# project-specific C++ code that gets built as a separate Ruby extension
namespace :cpp_callbacks do
	task :build, [:rubyOF_project] do |t, args|
		name_or_path = args[:rubyOF_project]
		name, path = RubyOF::Build.load_project(name_or_path)
		
			# TODO: consider turning #load_project into a block-taking method
			# I think that style would let you omit parameters if you wanted?
			# (e.g. I don't need the 'name' this time around)
		
		# PATH/ext/callbacks
		build_dir = File.join(path, 'ext', 'callbacks')
		
		# Generate makefile
		# and build the extension
		puts "=== Building project-specific C++ into a separate extension"
		
		Dir.chdir build_dir do
			run_i "ruby extconf.rb"
			run_i "make"
		end
		
	end
	
	task :clean, [:rubyOF_project] do |t, args|
		name_or_path = args[:rubyOF_project]
		name, path = RubyOF::Build.load_project(name_or_path)
		build_dir = File.join(path, 'ext', 'callbacks')
		
		Dir.chdir(build_dir) do
			begin 
				run_i "make clean"
			rescue StandardError => e
				# FIXME: Can't seem to catch, suppress, and continue
				puts "nothing to clean for #{build_dir}"
			end
		end
	end
	
	task :clobber, [:rubyOF_project] => :clean do |t, args|
		name_or_path = args[:rubyOF_project]
		name, path = RubyOF::Build.load_project(name_or_path)
		build_dir = File.join(path, 'ext', 'callbacks')
		
		[
			"Makefile"
		].each do |file_to_be_cleaned|
			Dir.chdir(build_dir) do
				FileUtils.rm file_to_be_cleaned if File.exist? file_to_be_cleaned
			end
		end
	end
end







module RubyOF
	module Build

class RubyBundlerAutomation
	def initialize
		
	end
	
	def install_core
		# begin
			puts "Bundler: Installing core dependencies"
			bundle_install(GEM_ROOT)
		# rescue StandardError => e
		# 	puts "Bundler had an error."
		# 	puts e
		# 	puts e.backtrace
		# 	exit
		# end
	end
	
	def uninstall_core
		bundle_uninstall(GEM_ROOT)
	end
	
	def install_project(path_or_name)
		begin
			name, path = RubyOF::Build.load_project(path_or_name)
			
			puts "Bundler: Installing dependencies for project '#{name}'"
			bundle_install(path)
		rescue StandardError => e
			puts "Bundler had an error."
			exit
		end
	end
	
	def uninstall_project(path_or_name)
		name, path = RubyOF::Build.load_project(path_or_name)
		bundle_uninstall(path)
	end
	
	private
	
	def bundle_install(path)
		Dir.chdir path do
			# run_i "unbuffer bundle install"
			# # NOTE: unbuffer does work here, but it assumes that you have that utility installed, and it is not installed by default
			# 	# sudo apt install expect
			
			
			run_pty "bundle install"
		end
	end
	
	def bundle_uninstall(path)
		Dir.chdir path do
			FileUtils.rm_rf "./.bundle"      # settings directory
			FileUtils.rm    "./Gemfile.lock" # lockfile
		end
	end
end

end
end

# === Manage ruby-level code
namespace :ruby do
	desc "testing"
	task :run, [:rubyOF_project] do |t, args|
		name, path = RubyOF::Build.load_project(args[:rubyOF_project])
		Dir.chdir path do
			puts "ruby level execution"
			
			exe_path = "./lib/main.rb"
			
			cmd = [
				'GALLIUM_HUD=fps,VRAM-usage',
				"ruby #{exe_path}"
			].join(' ')
			
			Kernel.exec(cmd)
		end
	end
	
	desc "testing"
	task :debug, [:rubyOF_project] do |t, args|
		name, path = RubyOF::Build.load_project(args[:rubyOF_project])
		Dir.chdir path do
			puts "ruby level execution"
			
			exe_path = "./lib/main.rb"
			p exe_path
			puts "Path to core file above."
			puts "Type: run 'PATH_TO_CORE_FILE'"
			puts "Remember: type 'q' to exit GDB."
			puts "=============================="
			puts ""
			Kernel.exec "gdb ruby"
		end
	end
	
	
	# manage ruby-level dependencies
	namespace :deps do
		obj = RubyOF::Build::RubyBundlerAutomation.new
		
		namespace :core do
			task :install do
				obj.install_core
			end
			
			task :uninstall do
				obj.uninstall_core
			end
		end
		
		
		namespace :project do
			task :install, [:rubyOF_project] do |t, args|
				obj.install_project(args[:rubyOF_project])
			end
			
			task :uninstall, [:rubyOF_project] do |t, args|
				obj.uninstall_project(args[:rubyOF_project])
			end
		end
	end
	
	
end






# cpp_wrapper_code   build / clean
# cpp_callbacks      build / clean / clobber
# cpp_project        build / clean / clobber


# # clean
# 	rake clean
# 	rake clean_cpp_wrapper[rubyOF_project]
# 	rake clean_project[rubyOF_project]
	
# 	rake oF:clean
# 		rake oF_deps:clean
# 			rake oF_deps:kiss:clean
# 			rake oF_deps:tess2:clean
	
# 	rake oF_project:clean
# 	rake oF_project:static_lib:clean
	
# 	rake cpp_wrapper_code:clean
	
# 	rake cpp_project:clean[rubyOF_project]
	
# 	rake cpp_callbacks:clean[rubyOF_project]

	

# # clobber
# 	rake clobber
	
# 	rake oF_deps:clobber
# 		rake oF_deps:kiss:clobber
# 		rake oF_deps:tess2:clobber
	
# 	rake cpp_project:clobber[rubyOF_project]
	
# 	rake cpp_callbacks:clobber[rubyOF_project]





# clean just a few things
desc "For reversing :build_cpp_wrapper"
task :clean_cpp_wrapper, [:rubyOF_project] => [
	'cpp_wrapper_code:clean',
	'cpp_project:clean',
	'cpp_callbacks:clean'
]

desc "For reversing :build_project"
task :clean_project, [:rubyOF_project] => [
	'cpp_project:clean',
	'cpp_callbacks:clean'
]

desc "For reversing :build_project"
task :clobber_project, [:rubyOF_project] => [
	'cpp_project:clobber',
	'cpp_callbacks:clobber'
] do |t, args|
	name, path = RubyOF::Build.load_project(args[:rubyOF_project])
	
	filepath = (Pathname.new(path) + 'Gemfile.lock')
	FileUtils.rm filepath if filepath.exist?
end





# add dependencies to default 'clean' / 'clobber' tasks
# NOTE: Don't edit the actual body of the task
task :clean   => [
	'oF_project:clean',
	'cpp_wrapper_code:clean',
	'cpp_project:clean',  # requires :rubyOF_project var
	'cpp_callbacks:clean' # requires :rubyOF_project var
]
task :clobber => ['oF_deps:clobber', 'oF:clean']



# TODO: Update clean tasks to remove the makefile after running "make clean"
# (the main Makefile is removed on 'clean', so I think all other auto-generated makefiles should follow suit)



desc "Set up environment on a new machine."
task :setup => [
	# 'oF:download_libs',
	'oF_deps:inject', # NOTE: injecting will always force a new build of oF core
	'oF:build',
	'oF_project:build'
] do
	FileUtils.mkdir_p "bin/data"
	FileUtils.mkdir_p "bin/lib" # <-- DYNAMIC_LIB_PATH
	
	# -- bin/projects/ and specifically the 'boilerplate' project should 
	#    always be present, and so the system does not have to manually
	#    establish those folders
	# FileUtils.mkdir_p "bin/projects"
	# FileUtils.mkdir_p "bin/projects/boilerplate/bin"
	# FileUtils.mkdir_p "bin/projects/boilerplate/ext"
	# FileUtils.mkdir_p "bin/projects/boilerplate/lib"
end



# desc "Copy oF dynamic libs to correct location"
task :install_oF_dynamic_libs do
	puts "=== Copying OpenFrameworks dynamic libs..."
	
	# -rpath flag specifies where to look for dynamic libraries
	# (the system also has some paths that it checks for, but these are the "local dlls", basically)
	
	# NOTE: DYNAMIC_LIB_PATH has been passed to -rpath
	# (specified in extconf.rb)
	
	src = File.expand_path(
		        "./libs/fmodex/lib/#{PLATFORM}/libfmodex.so",
	           OF_ROOT
	      )
	dest = DYNAMIC_LIB_PATH
	FileUtils.copy(src, dest)
	
	# (actual DYNAMIC_LIB_PATH directory created explictly in :setup task above)
	# (does not reference the constant)
	
	# TODO: consider copying the ext/oF_apps/testApp/bin/data/ directory as well
end



# For working on a normal OpenFrameworks project in pure C++
desc "Build a normal OpenFrameworks project in pure C++"
task :build_cpp => ['oF:build', 'oF_project:build']



# For integrating Rice bindings with the current RubyOF project
# (can edit addons, oF core, oF project, Rice bindings, or RubyOF project)
# 
# Assumes 'setup' has been run.
# 
# Build dependencies shifted from explict to implied, (assumes task has run)
# so that you don't duplicate the work being done in :setup.
# This way, the build process will go a little faster.
desc "For updating Rice code, and testing with current RubyOF project"
task :build_cpp_wrapper, [:rubyOF_project] => [
	'oF_project:build',                  # implicitly requires oF:build
	'oF_project:export_build_variables', # implicitly requires oF_project:build
	'oF_project:static_lib:build',
	
	'cpp_wrapper_code:build', # implicitly requires oF_project:build
	# ^ multiple steps:
	#   +  extconf.rb -> makefile
	#   +  run the makefile -> build ruby dynamic lib (.so)
	#   +  move ruby dynamic lib (.so) into proper position
	#   +  ALSO rebuilds the clang symbol DB as necessary.
	
	:install_oF_dynamic_libs,
] do
	
	puts ">>> BUILD COMPLETE <<<"
	
end


# For using stable bindings with a custom blend of C++ and Ruby
# (can edit addons, or RubyOF project)
# 
# Assumes 'setup' has been run
# Assumes 'build_cpp_wrapper' has been run
desc "For using stable bindings with a custom blend of C++ and Ruby"
task :build_project, [:rubyOF_project] => [
	'cpp_project:build_addons_lib',
	
	'cpp_project:build',
	'cpp_callbacks:build'
] do |t, args|
	puts ">>> BUILD COMPLETE <<<"
end

# NOTE: parameters to rake task are passed to all dependencies as well
# source: https://stackoverflow.com/questions/12612323/rake-pass-parameters-to-dependent-tasks



# --- pathway ---
desc "Build up from a newly cloned repo"
task :full_build, [:rubyOF_project] => [
	:setup,
	:build_cpp_wrapper,
	:build_project
]






# (tasks that do not need the 'project' argument will ignore it)
# desc "Run default build task (:build_cpp_wrapper)"
# task :build, [:rubyOF_project] => :build_cpp_wrapper
desc "Run main build tasks (:build_cpp_wrapper and :build_project)"
task :build, [:rubyOF_project] => [
	:build_cpp_wrapper,
	:build_project
]



# task :run => 'oF_project:run'

desc "Run the entire project, through the ruby level"
task :run, [:rubyOF_project] => 'ruby:run'
	# can't just say 'run' any more.
	# need to specify what project is being run

task :build_and_run, [:rubyOF_project]  => [:build, :run] do
	
end





desc "Assumes build options are set to make 'Debug' target"
task :debug_project => [
	'oF:build',
	'oF_project:build',                  # implicitly requires oF:build
	'oF_project:debug'
] do
	
end

desc "Debug application through the Ruby level with GDB"
task :debug, [:rubyOF_project]  => 'ruby:debug'



load './rake/examine.rake'
