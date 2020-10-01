require 'rake/testtask'
require 'rake/clean'

require 'pathname'
require 'fileutils'
require 'open3'
require 'yaml' # used for config files


require './common'
# ^ this file declares GEM_ROOT constant, other constants, and a some functions

load './rake/helper_functions.rb'


# ==== rake argument documentation ====
# :rubyOF_project		name of project (if under project directory)
#                         OR
#                    full path to project (if stored elsewhere)
# =====================================



# 
# check that all environment variables are set
# 

# If the current working directory is under the GEM_ROOT/bin/projects/<PROJ_NAME_HERE> structure, you can figure out the project name by examining the path. Otherwise, the project name must be set using the environment variable RUBYOF_PROJECT
# ex)  env RUBYOF_PROJECT="proj_name" rake build_and_run

root = Pathname.new(GEM_ROOT)
# p root
current_dir = Pathname.new Rake.original_dir
puts "current: #{current_dir}"
project_basepath = 
	current_dir.ascend.each_cons(2)
	.select{ |here, parent|  parent == root/'bin'/'projects' }.flatten.first

if project_basepath.nil? # may be nil if we are not in that part of the tree
	# Can't determine the project name based on the working directory,
	# so check the environment variable as a last resort:
	
	var_name = 'RUBYOF_PROJECT'
	if ENV[var_name].nil?
		msg = [
			"-------",
			"ERROR: Can't automatically determine project name.",
			"",
			"Must either run rake from within a project directory",
			"under the '[GEM_ROOT]/bin/projects subtree'",
			"or set environment variable '#{var_name}'",
			"-------"
		].join("\n") 
		raise msg
	else
		# NO-OP
		# variable is already set, so do nothing
		
	end
	
else
	# environment variable is not set, but can be automatically determined
	
	# p project_basepath.basename.to_s
	ENV['RUBYOF_PROJECT'] = project_basepath.basename.to_s
	
	# NOTE: must set environment variable rather than constant, otherwise other parts of the system will be unable to access it ( like bin/main.rb )
end

# p project_basepath


# Rake changes the working directory to be the directory where the Rakefile is, so how do you get original working directory of the terminal when Rake was called?
	# task :whereami do
	# puts Rake.original_dir
	# end
	#
	# – Jim W.
# src: https://www.ruby-forum.com/t/q-how-can-a-rake-task-know-the-callers-directory/81868/10








# generate depend file for gcc dependencies
# sh "gcc -MM *.c > depend"






# + uncompress OF folder -> "openFrameworks"
#   (make sure to rename, dropping the version number etc)
# + build shared library for OF core
# + rename shared library files so they end in .so as expected
# + build static library for OF core

# (no need to muck with dependencies or anything like that)

	# (run a OF project and export build variables)
	# + build core wrapper
	# + build project wrapper

	# + run project from the Ruby level


namespace :oF do
	# desc "Download openFrameworks libraries (build deps)"
	# task :download_libs do
	# 	run_i "ext/openFrameworks/scripts/linux/download_libs.sh"
	# 	# ^ this script basically just triggers another script:
	# 	#   ext/openFrameworks/scripts/dev/download_libs.sh
	# end
	## (don't need to download libs with a packaged released. only for git repo)
	
	
	desc "Build core - shared lib"
	task :build_dynamic do
		puts "=== Building OpenFrameworks core as DYNAMIC library..."
		
		puts "-- building..."
		Dir.chdir "#{OF_ROOT}/scripts/linux/" do
			run_i "env SHAREDCORE=1 CFLAGS=-fPIC ./compileOF.sh -j#{NUMBER_OF_CORES}"
		end
		
		Dir.chdir "#{OF_ROOT}/libs/openFrameworksCompiled/lib/#{PLATFORM}/" do
			{
				"libopenFrameworks.a"      => "libopenFrameworks.so",
				"libopenFrameworksDebug.a" => "libopenFrameworksDebug.so",
			}.each do |current_name, new_name|
				puts "-- renaming..."
				FileUtils.mv current_name, new_name
				
				puts "-- coping to final destination: #{DYNAMIC_LIB_PATH}"
				FileUtils.cp new_name, DYNAMIC_LIB_PATH
			end
		end
		
		
		puts "-- done!"
	end
	
	desc "Build core - static lib"
	task :build_static do
		puts "=== Building OpenFrameworks core as STATIC library..."
		Dir.chdir "#{OF_ROOT}/scripts/linux/" do
			run_i "env CFLAGS=-fPIC ./compileOF.sh -j#{NUMBER_OF_CORES}"
		end
	end
	
	desc "Clean openFrameworks core (ubuntu)."
	task :clean do
		path = "libs/openFrameworksCompiled/project"
		path = File.expand_path(path, OF_ROOT)
		Dir.chdir path do
			run_i "make clean" # clean up the core
		end
	end
	
	desc "Clean and Rebuild oF core (ubuntu)."
	task :rebuild do
		run_task('oF:clean')
		run_task('oF:build')
	end
	
	task :build => [:build_dynamic, :build_static]
	# must build dynamic first, and then static,
	# otherwise the temporary files from dynamic build
	# will clobber the static libraries.
	
	
	
	
	desc "Build the project generator."
	task :compilePG =>  :build_static do
		Dir.chdir File.join(GEM_ROOT, "ext/openFrameworks/scripts/linux/") do
			run_i "./compilePG.sh"
		end
	end
	
	# NOTE: Project generator can update existing projects, including specifying the addons used for a particular project.
	desc "Create a new openFrameworks project in the correct directory."
	task :project_generator, [:ofProjectName] do |t, args|
		project = args[:ofProjectName]
		
		if project.nil?
			raise "ERROR: must specify oF_project_name"
		end
		
		
		# NOTE: These paths need to be full paths, because they are being passed to another system, which is executing from a different directory.
		full_dir = "#{OF_ROOT}/apps/projectGenerator/commandLine/bin"
		
		
		a = File.join(GEM_ROOT, "ext", "openFrameworks")
		b = File.join(GEM_ROOT, "ext", "oF_apps", project)
		
		Dir.chdir full_dir do
			# p Dir.pwd
			
			run_i "./projectGenerator -o\"#{a}\" #{b}" 
		end
		
	end
	
end



# defines RubyOF::Build.create_project and RubyOF::Build.load_project
require File.join(GEM_ROOT, 'build', 'build.rb')




# --- helpers
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




# --- core logic

# TARGET
# NUMBER_OF_CORES
def build_oF_app(name, sketch_root)
	puts "=== Building #{name}..."
	Dir.chdir sketch_root do
		# TARGET specifies whether to build "Debug" or "Release" build
		
		begin
			run_i "env CFLAGS=-fPIC  make #{TARGET} -j#{NUMBER_OF_CORES}"
		rescue StandardError => e
			puts "ERROR: Could not build #{name}."
			exit
		end
		# FileUtils.touch 'oF_project_build_timestamp'
	end
end

# TARGET
def export_oF_build_vars(sketch_root, raw_build_variable_file)
	puts "=== Exporting oF project build variables..."
	
	Dir.chdir sketch_root do
		swap_makefile(sketch_root, "Makefile", "Makefile.static_lib") do
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

def reformat_build_vars(raw_build_variable_file, build_variable_file)
	puts "=== reformatting..."
	data = YAML.load_file(raw_build_variable_file)
			
	File.open(build_variable_file, "w") do |f|
		f.puts parse_build_variable_data(data).to_yaml
	end
	
	puts "=> Variables written to '#{build_variable_file}'"
	puts ""
end

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
	
	# NOTE: This is part of a normal extconf build, but I don't want it.
	#       I will move the .so as part of a separate task.
	# # puts "=== Moving dynamic library into correct location..."
	# FileUtils.cp "ext/#{NAME}/#{NAME}.so", "lib/#{NAME}"
	
	
	puts "=> C extension build complete!"
end




# 1) build testApp using oF build system
# 2) export build vars from testApp
# 3) reverse engineer build vars for use in ruby's extconf.rb system
# 4) use extconf.rb and Rice to build dynamic library of wrapper for *core oF* functionality
# 5) move dynamic library into easy-to-load location

# Assumes 'setup' has been run.
desc "Namespace: update core bindings"
namespace :core_wrapper do
	root = Pathname.new(GEM_ROOT)
	
	c_extension_dir = root/"ext"/NAME
	c_extension_file = c_extension_dir/"#{NAME}.so"
	install_location = "lib/#{NAME}/#{NAME}.so"
	# NOTE: This only works for linux, because it explicitly uses the ".so" extension
	
	
	
	oF_app_executable = 
		Array.new.tap{ |x|
			x << OF_SKETCH_NAME
			
			suffix = OF_DEBUG ? "debug" : ""
			x << suffix unless suffix.nil?
		}.join('_')
	
	path_to_exe = Pathname.new(OF_SKETCH_ROOT)/'bin'/oF_app_executable
	
	
	
	# This build system makes it so that build variables are only exported again as necessary. This way, you can use a change in the build variables to trigger other events.
	task :build => [
		:build_app,		         # build testApp using oF build system
		:build_c_extension,     # export build vars -> reformat -> build wrapper
		:move_dynamic_lib       # move dynamic library into easy-to-load location
	]
	
	task :run_app do
		Dir.chdir Pathname.new(OF_SKETCH_ROOT)/'bin' do
			begin
				run_i "./testApp_debug"
			rescue StandardError => e
				puts "ERROR: Could not build #{name}."
				exit
			end
		end
	end
	
	# 1) build testApp using oF build system
	task :build_app do
		build_oF_app("core oF sketch", OF_SKETCH_ROOT)
	end
	
	# 2) export build vars from testApp
	file OF_RAW_BUILD_VARIABLE_FILE => [
		Pathname.new(OF_SKETCH_ROOT)/'Makefile.static_lib',
		__FILE__,      # if the Rake task changes, then update the output file
		COMMON_CONFIG, # if config variables change, then build may be different
		path_to_exe    # if :build_app produces new binary, then re-export vars
	] do
		run_task 'project_wrapper:create_addons_app'
		# ^ Copy over core app to the particular project.
		#   only copy over app when the output of :build_app changes,
		#   which is when this task will execute
		
		export_oF_build_vars(OF_SKETCH_ROOT, OF_RAW_BUILD_VARIABLE_FILE)
	end
	
	# 3) reverse engineer build vars for use in ruby's extconf.rb system
	file OF_BUILD_VARIABLE_FILE => OF_RAW_BUILD_VARIABLE_FILE do
		reformat_build_vars(OF_RAW_BUILD_VARIABLE_FILE, OF_BUILD_VARIABLE_FILE)
	end
	
	# 4) use extconf.rb and Rice to build dynamic library of wrapper for core oF functionality
	
	# Mimic RubyGems gem install procedure, for testing purposes.
	# * run extconf
	# * execute the resultant makefile
	# * move the .so to it's correct location
	task :build_c_extension => c_extension_file
		
		extension_dependencies = Array.new.tap do |deps|
			# Ruby / Rice CPP filesf
			deps.concat Dir.glob("ext/#{NAME}/**/*{.cpp,.h}")
			# deps.concat Dir.glob("ext/#{NAME}/*{.rb,.c}")
			
			deps << "ext/#{NAME}/extconf.rb"
			deps << "ext/#{NAME}/extconf_common.rb"
			deps << "ext/#{NAME}/extconf_printer.rb"
			deps << __FILE__ # depends on this Rakefile
			deps << OF_BUILD_VARIABLE_FILE
		end
		
		file c_extension_file => extension_dependencies do
			puts "=== building core wrapper..."
			build_c_extension(c_extension_dir)
		end
		
	
	# 5) move dynamic library into easy-to-load location]
	task :move_dynamic_lib do
		puts "=== moving core dynamic lib to easy-to-load location"
		FileUtils.cp c_extension_file, install_location
		puts "=> DONE!"
	end
	
	
	
	
	
	
	
	# NOTE: clobber task will removed all .so files, including the dynamic library created in this namespace
	
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
end



# arguments:   [project_name]

# Projects use some combination of Ruby and C++ to build on the framework,
# and accomplish a specific goal.

# same basic 5 step process as before, but with some additions
# + need to perform some patching of the oF project used previously,
#   as position of the OpenFrameworks folder relative to the project
#   is different than position relative to the core wrapper code directory.

# Assumes 'setup' has been run.
desc "Namespace: update project-specific C++ code"
namespace :project_wrapper do
	root = Pathname.new(GEM_ROOT)
	
	# TODO: turn project_name into an argument (will be given to all tasks)
	# NOTE: currently, project name needs to be set at this level. all other build variables declared in this top section require that project_name is set.
	# GOT IT! => use environment variable instead of rake argument to set project name. This way, the project name will be visible everywhere.
	# to run from command line:
	# $ env RUBYOF_PROJECT="youtube" rake execution:build_and_run
	
	project_name = ENV['RUBYOF_PROJECT']
	project_dir  = root/'bin'/'projects'/project_name
	
	
	addons_app_root     = project_dir/'ext'/'addons_app'
	addons_sketch_root    = addons_app_root/OF_SKETCH_NAME
	raw_build_variable_file = addons_sketch_root/'raw_oF_variables.yaml'
	build_variable_file     = addons_sketch_root/'oF_build_variables.yaml'
	
	
	c_extension_dir     = project_dir/'ext'/'c_extension'
	c_extension_file      = c_extension_dir/"#{NAME}.so"
	install_location    = project_dir/'bin'/'lib'/"#{NAME}_project.so"
	# NOTE: This only works for linux, because it explicitly uses the ".so" extension
	
	
	x = addons_app_root
		source_addons_file = x/'addons.make'
		active_addons_file = x/OF_SKETCH_NAME/'addons.make'
		
		source_oF_project_makefile = x/'Makefile'
		active_oF_project_makefile = x/OF_SKETCH_NAME/'Makefile'
		
		source_oF_static_lib_makefile = x/'Makefile.static_lib'
		active_oF_static_lib_makefile = x/OF_SKETCH_NAME/'Makefile.static_lib'
	
	
	
	
	
	oF_app_executable = 
		Array.new.tap{ |x|
			x << OF_SKETCH_NAME
			
			suffix = OF_DEBUG ? "debug" : ""
			x << suffix unless suffix.nil?
		}.join('_')
	
	path_to_exe = Pathname.new(addons_sketch_root)/'bin'/oF_app_executable
	
	
	
	# This build system makes it so that build variables are only exported again as necessary. This way, you can use a change in the build variables to trigger other events.
	task :build => [
		:build_app,		         # build testApp using oF build system
		:build_c_extension,     # export build vars -> reformat -> build wrapper
		:move_dynamic_lib       # move dynamic library into easy-to-load location
	]
	
	
	# 1) build testApp using oF build system
	task :build_app => [
		active_addons_file,
		active_oF_project_makefile,
		active_oF_static_lib_makefile
	] do
		build_oF_app("addons app", addons_sketch_root)
	end
	
	# 2) export build vars from testApp
	file raw_build_variable_file => [
		Pathname.new(addons_sketch_root)/'Makefile.static_lib',
		__FILE__,      # if the Rake task changes, then update the output file
		COMMON_CONFIG, # if config variables change, then build may be different
		path_to_exe    # if :build_app produces new binary, then re-export vars
	] do
		export_oF_build_vars(addons_sketch_root, raw_build_variable_file)
	end
	
	# 3) reverse engineer build vars for use in ruby's extconf.rb system
	file build_variable_file => raw_build_variable_file do
		reformat_build_vars(raw_build_variable_file, build_variable_file)
	end
	
	# 4) use extconf.rb and Rice to build dynamic library of wrapper for core oF functionality
	
	# Mimic RubyGems gem install procedure, for testing purposes.
	# * run extconf
	# * execute the resultant makefile
	# * move the .so to it's correct location
	task :build_c_extension => c_extension_file
	
		extension_dependencies = Array.new.tap do |deps|
			# Ruby / Rice CPP files
			deps.concat Dir.glob File.join(c_extension_dir, "**/*{.cpp,.h}")
			# deps.concat Dir.glob("ext/#{NAME}/*{.rb,.c}")
			
			deps << c_extension_dir/"extconf.rb"
			# deps << "ext/#{NAME}/extconf_common.rb"
			deps << "ext/#{NAME}/extconf_printer.rb"
			deps << __FILE__ # depends on this Rakefile
			deps << build_variable_file
		end
	
		file c_extension_file => extension_dependencies do
			puts "=== building project C++ code..."
			build_c_extension(c_extension_dir)
		end
		
	
	# 5) move dynamic library into easy-to-load location]
	task :move_dynamic_lib do
		puts "=== moving project dynamic lib to easy-to-load location"
		FileUtils.cp c_extension_file, install_location
		puts "=> DONE!"
	end
	
	
	
	
	# This helper task will be called by core_wrapper:build_app as necessary. Only when the core app is changed will the addons app be updated.
	task :create_addons_app do
		puts "=== Initializing project-specific addons app"
		# + remove old oF project directory, if one exists
		# + copy testApp from core wrapper
		# + move addons.make for this project into app folder
		# + move custom Makefile into app folder
		
		project_dir = addons_app_root/OF_SKETCH_NAME
		FileUtils.rm_rf project_dir if project_dir.exist?
		
		FileUtils.cp_r OF_SKETCH_ROOT, addons_app_root/OF_SKETCH_NAME
		
		FileUtils.cp source_addons_file, active_addons_file
		FileUtils.cp source_oF_project_makefile, active_oF_project_makefile
		FileUtils.cp source_oF_static_lib_makefile, active_oF_static_lib_makefile
	end
	
	
	
	# These helper tasks move configuration files into the actual oF project that will use them. The oF project is merely a driver for these elements. Often, a new copy of that driver will have to be copied in. Thus, I place these elements outside that folder, so the system can automatically patch at will.
	# 
	# Set as prereqs by the first task in the :project_wrapper namespace, so that this entire set of things will rebuild if these files have been modified.
	# 
	file active_addons_file => source_addons_file do
		FileUtils.cp source_addons_file, active_addons_file
	end
	
	file active_oF_project_makefile => source_oF_project_makefile do
		FileUtils.cp source_oF_project_makefile, active_oF_project_makefile
	end
	
	file active_oF_static_lib_makefile => source_oF_static_lib_makefile do
		FileUtils.cp source_oF_static_lib_makefile, active_oF_static_lib_makefile
	end
	
	
	
	
	
	
	
	# NOTE: clobber task will removed all .so files, including the dynamic library created in this namespace
	
	task :clean do
		# NOTE: cleaning oF sketch also cleans addons
		Dir.chdir addons_sketch_root do
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
	
	
	
	
	# # 2.4) extract just the addons info from the build var data
	# file addons_data => build_variable_file do
	# 	puts "== extracting addon data..."
		
	# 	Dir.chdir addons_app_dir do
	# 		data = YAML.load_file(build_variable_file)
	# 		data['OF_PROJECT_ADDONS_OBJS']
			
			
	# 		keys = %w[
	# 			ALL_INSTALLED_ADDONS
	# 			VALID_PROJECT_ADDONS
	# 			PROJECT_ADDONS
	# 			OF_PROJECT_ADDONS_OBJS
	# 			PROJECT_ADDONS_CFLAGS
	# 			PROJECT_ADDONS_DATA
	# 			PROJECT_ADDONS_FRAMEWORKS
	# 			PROJECT_ADDONS_INCLUDES
	# 			PROJECT_ADDONS_LDFLAGS
	# 			PROJECT_ADDONS_LIBS
	# 		]
	# 		final = 
	# 			data.select {  |k,v|
	# 				keys.include? k
	# 			}
			
			
	# 		filepath = addons_data
	# 		File.open(filepath, "w") do |f|
	# 			f.puts final.to_yaml
	# 		end
			
	# 		puts "=> Variables written to '#{filepath}'"
	# 		puts ""
	# 	end
	# 		# OF_PROJECT_ADDONS_OBJS
	# 		# PROJECT_ADDONS
	# 		# PROJECT_ADDONS_SOURCE_FILES
	# 		# PARSED_ADDONS_FILTERED_LIBS_SOURCE_INCLUDE_PATHS
	# 		# addon
	# 		# PROJECT_ADDONS_LDFLAGS
	# 		# PLATFORM_REQUIRED_ADDONS
	# 		# PARSED_ADDONS_LIBS_SOURCE_INCLUDES
	# 		# B_PROCESS_ADDONS: 'yes'
	# 		# PARSED_ADDONS_LIBS_SOURCES
	# 		# PARSED_ADDONS_FILTERED_INCLUDE_PATHS
	# 		# ADDONS_INCLUDES_FILTER
	# 		# TMP_PROJECT_ADDONS_PKG_CONFIG_LIBRARIES
	# 		# PROJECT_ADDONS_OBJ_FILES
	# 		# PROJECT_ADDONS_FRAMEWORKS
	# 		# PARSED_ADDONS_LIBS_PLATFORM_LIB_PATHS
	# 		# PARSED_ADDONS_SOURCE_INCLUDES
	# 		# INVALID_PROJECT_ADDONS
	# 		# INVALID_GLOBAL_ADDONS
	# 		# TMP_PROJECT_ADDONS_SOURCE_FILES
	# 		# PARSED_ADDONS_SOURCE_PATHS
	# 		# TMP_PROJECT_ADDONS_OBJ_FILES
	# 		# VALID_PROJECT_ADDONS
	# 		# PARSED_ADDONS_LIBS_SOURCE_PATHS
	# 		# PARSED_ADDONS_SOURCE_FILES
	# 		# TMP_PROJECT_ADDONS_LDFLAGS
	# 		# ADDONS_SOURCES_FILTER
	# 		# TMP_PROJECT_ADDONS_FRAMEWORKS
	# 		# PARSED_ADDONS_LIBS_INCLUDES_PATHS
	# 		# PROJECT_ADDONS_INCLUDES
	# 		# PARSED_ADDONS_FILTERED_LIBS_SOURCE_PATHS
	# 		# REQUESTED_PROJECT_ADDONS
	# 		# PROJECT_ADDONS_OBJ_PATH
	# 		# OF_PROJECT_ADDONS_DEPS
	# 		# parse_addons_sources
	# 		# parse_addons_libraries
	# 		# parse_addons_includes
	# 		# TMP_PROJECT_ADDONS_INCLUDES
	# 		# PARSED_ADDONS_FILTERED_LIBS_INCLUDE_PATHS
	# 		# ADDON_INCLUDE_CFLAGS
	# 		# PARSED_ADDONS_INCLUDES
	# 		# PROJECT_ADDONS_CFLAGS
	# 		# PARSED_ADDONS_OFX_SOURCES
	# 		# PROJECT_ADDONS_DATA
	# 		# PARSED_ADDONS_LIBS_INCLUDES
	# 		# ADDON_LIBS
	# 		# PROJECT_ADDONS_LIBS
	# 		# ALL_INSTALLED_ADDONS
			
	# 		# -------------------------
	# 		# raw data above, organized data below
			
			
			
	# 		# B_PROCESS_ADDONS: 'yes'
			
	# 		# ALL_INSTALLED_ADDONS
	# 		# INVALID_GLOBAL_ADDONS
	# 		# INVALID_PROJECT_ADDONS
	# 		# VALID_PROJECT_ADDONS
	# 		# PLATFORM_REQUIRED_ADDONS
			
	# 		# addon
	# 		# ADDON_INCLUDE_CFLAGS
	# 		# ADDON_LIBS
	# 		# ADDONS_INCLUDES_FILTER
	# 		# ADDONS_SOURCES_FILTER
	# 		# OF_PROJECT_ADDONS_DEPS
	# 		# OF_PROJECT_ADDONS_OBJS
			
	# 		# PROJECT_ADDONS
	# 		# PROJECT_ADDONS_CFLAGS
	# 		# PROJECT_ADDONS_DATA
	# 		# PROJECT_ADDONS_FRAMEWORKS
	# 		# PROJECT_ADDONS_INCLUDES
	# 		# PROJECT_ADDONS_LDFLAGS
	# 		# PROJECT_ADDONS_LIBS
	# 		# PROJECT_ADDONS_OBJ_FILES
	# 		# PROJECT_ADDONS_OBJ_PATH
	# 		# REQUESTED_PROJECT_ADDONS
	# 		# PROJECT_ADDONS_SOURCE_FILES
			
			
	# 		# PARSED_ADDONS_FILTERED_INCLUDE_PATHS
	# 		# PARSED_ADDONS_FILTERED_LIBS_INCLUDE_PATHS
	# 		# PARSED_ADDONS_FILTERED_LIBS_SOURCE_INCLUDE_PATHS
	# 		# PARSED_ADDONS_FILTERED_LIBS_SOURCE_PATHS
	# 		# PARSED_ADDONS_INCLUDES
	# 		# PARSED_ADDONS_LIBS_INCLUDES
	# 		# PARSED_ADDONS_LIBS_INCLUDES_PATHS
	# 		# PARSED_ADDONS_LIBS_PLATFORM_LIB_PATHS
	# 		# PARSED_ADDONS_LIBS_SOURCE_INCLUDES
	# 		# PARSED_ADDONS_LIBS_SOURCE_PATHS
	# 		# PARSED_ADDONS_LIBS_SOURCES
	# 		# PARSED_ADDONS_OFX_SOURCES
	# 		# PARSED_ADDONS_SOURCE_FILES
	# 		# PARSED_ADDONS_SOURCE_INCLUDES
	# 		# PARSED_ADDONS_SOURCE_PATHS
			
			
	# 		# TMP_PROJECT_ADDONS_FRAMEWORKS
	# 		# TMP_PROJECT_ADDONS_INCLUDES
	# 		# TMP_PROJECT_ADDONS_LDFLAGS
	# 		# TMP_PROJECT_ADDONS_OBJ_FILES
	# 		# TMP_PROJECT_ADDONS_PKG_CONFIG_LIBRARIES
	# 		# TMP_PROJECT_ADDONS_SOURCE_FILES
	# end
	
	
		
	# TODO: update extension file path
	# TODO: update extension dependencies
end



# Put everything together
# + load dynamic library for core wrapper
# + load dynamic library for a particular project
# + require Ruby code for that same project
# + open and run the Window associated with that project
# NOTE: Currently will only execute the 'youtube' project. Need to reconfigure build system so that any arbitrary project can be run.


# NOTE: Project name must always be specified as
#       an environment variable, ENV['RUBYOF_PROJECT']
#       for all tasks.









# =============
# manage ruby-level dependencies
# =============
def bundle_install(path)
	Dir.chdir path do
		# run_i "unbuffer bundle install"
		# # NOTE: unbuffer does work here, but it assumes that you have that utility installed, and it is not installed by default
		# 	# sudo apt install expect
		
		begin
			run_pty "bundle install"
		rescue StandardError => e
			puts "Bundler had an error."
			exit
		end
	end
end

def bundle_uninstall(path)
	Dir.chdir path do
		FileUtils.rm_rf "./.bundle"      # settings directory
		FileUtils.rm    "./Gemfile.lock" # lockfile
		
		# filepath = (Pathname.new(path) + 'Gemfile.lock')
		# FileUtils.rm filepath if filepath.exist?
	end
end

namespace :ruby_deps do
	desc "use Bundler to install ruby dependencies"
	task :install do
		# core dependencies
		puts "Bundler: Installing core dependencies"
		bundle_install(GEM_ROOT)
		
		# project specific
		proj_path = Pathname.new(GEM_ROOT)/'bin'/'projects'/ENV['RUBYOF_PROJECT']
		name, path = RubyOF::Build.load_project(proj_path)
		puts "Bundler: Installing dependencies for project '#{name}'"
		bundle_install(path)
	end
	
	desc "remove dependencies installed by Bundler"
	task :uninstall do
		# core dependencies
		puts "Bundler: Uninstalling core dependencies"
		bundle_uninstall(GEM_ROOT)
		
		# project specific
		proj_path = Pathname.new(GEM_ROOT)/'bin'/'projects'/ENV['RUBYOF_PROJECT']
		name, path = RubyOF::Build.load_project(proj_path)
		puts "Bundler: Uninstalling dependencies for project '#{name}'"
		bundle_uninstall(path)
	end
	
	task :reinstall => [:uninstall, :install]
end
# =============
# =============


task :setup => [
	'ruby_deps:install'
]


# + uncompress OF folder -> "openFrameworks"
#   (make sure to rename, dropping the version number etc)
	# env RUBYOF_PROJECT="youtube" rake oF:build_dynamic
# + build shared library for OF core
# + rename shared library files so they end in .so as expected
# + move .so files to DYNAMIC_LIB_PATH so they can be linked against later
	# env RUBYOF_PROJECT="youtube" rake oF:build_static
# + build static library for OF core

# (no need to muck with dependencies or anything like that)

# (run a OF project and export build variables)
	# env RUBYOF_PROJECT="youtube" rake core_wrapper:build
# + build core wrapper
# + build project wrapper

# + run project from the Ruby level



task :build_and_run => [:build, :run] 




# NOTE: parameters to rake task are passed to all dependencies as well
# source: https://stackoverflow.com/questions/12612323/rake-pass-parameters-to-dependent-tasks

# For working on a normal OpenFrameworks project in pure C++
desc "Testing only: Build a normal OpenFrameworks project in pure C++"
task :build_cpp => ['oF:build', 'core_wrapper:build_app']


desc "Build up from a newly cloned repo"
task :full_build => [
	:setup,
	:build
]


desc "Build core wrapper and project wrapper for given project"
task :build => [
	'core_wrapper:build',
	'project_wrapper:build'
]


# NOTE: Project name must always be specified as
#       an environment variable, ENV['RUBYOF_PROJECT']
#       for all tasks.
desc "run entire project"
task :run do
	root = Pathname.new(GEM_ROOT)
	
	core_install_location    = root/'lib'/NAME/"#{NAME}.so"
	
	project_name = ENV['RUBYOF_PROJECT']
	project_dir  = root/'bin'/'projects'/project_name
	project_install_location = project_dir/'bin'/'lib'/"#{NAME}_project.so"
	
	Dir.chdir project_dir do
		puts "ruby level execution"
		
		exe_path = "./lib/main.rb"
		
		cmd = [
			'GALLIUM_HUD=fps,VRAM-usage',
			"ruby #{exe_path}"
		].join(' ')
		
		Kernel.exec(cmd)
	end
end

namespace :callgrind do
	CALLGRIND_FILE = 'callgrind_RubyCpp.out'
	
	desc "Profile C++ code (requires instrumentation) [ save to file in project ]"
	task :run do
		root = Pathname.new(GEM_ROOT)
		
		core_install_location    = root/'lib'/NAME/"#{NAME}.so"
		
		project_name = ENV['RUBYOF_PROJECT']
		project_dir  = root/'bin'/'projects'/project_name
		project_install_location = project_dir/'bin'/'lib'/"#{NAME}_project.so"
		
		Dir.chdir project_dir do
			puts "ruby level execution"
			
			exe_path = "./lib/main.rb"
			
			
			cmd = [
				'env GALLIUM_HUD=fps,VRAM-usage',
				"valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file='#{CALLGRIND_FILE}'",
				"ruby #{exe_path}"
			].join(' ')
			
			Kernel.exec(cmd)
		end
	end
	
	desc "Visualize callgrind profiling data (load from file in project)"
	task :view do
		root = Pathname.new(GEM_ROOT)
		
		core_install_location    = root/'lib'/NAME/"#{NAME}.so"
		
		project_name = ENV['RUBYOF_PROJECT']
		project_dir  = root/'bin'/'projects'/project_name
		project_install_location = project_dir/'bin'/'lib'/"#{NAME}_project.so"
		
		Dir.chdir project_dir do
			puts "loading callgrind file..."
			
			cmd = [
				"kcachegrind '#{CALLGRIND_FILE}'"
			].join(' ')
			
			Kernel.exec(cmd)
		end
	end
end

desc "debug project using GDB"
task :debug do
	unless TARGET == 'Debug'
		warning_message = [
			"WARNING: Trying to debug, but c++ debug build is not being used.",
			"         May want to set OF_DEBUG flag in common.rb,",
			"         and run 'rake build' before trying to debug again."
		].join("\n")
		warn warning_message
	end
	# name, path = RubyOF::Build.load_project(args[:rubyOF_project])
	
	root = Pathname.new(GEM_ROOT)
	
	core_install_location    = root/'lib'/NAME/"#{NAME}.so"
	
	project_name = ENV['RUBYOF_PROJECT']
	project_dir  = root/'bin'/'projects'/project_name
	project_install_location = project_dir/'bin'/'lib'/"#{NAME}_project.so"
	
	Dir.chdir project_dir do
		puts "ruby level execution"
		puts ""
		puts "Remember: Type 'r' or 'run' to start"
		puts "Remember: type 'q' to exit GDB."
		puts "=============================="
		puts ""
		
		exe_path = "./lib/main.rb"
		# ENV['RUBYOF_RUBY_MAIN'] = exe_path
		# https://stackoverflow.com/questions/6121094/how-do-i-run-a-program-with-commandline-args-using-gdb-within-a-bash-script
		Kernel.exec "gdb --args ruby #{exe_path}"
	end
end












module RubyOF
	module Build


end
end


# TODO: implement 'create_project' rake task
task :create_project, [:project_name] do |t, args|
	args[:project_name]
end










load './rake/clean_and_clobber.rb'

# add dependencies to default 'clean' / 'clobber' tasks
# NOTE: Don't edit the actual body of the task
task :clean => [
	'core_wrapper:clean',
	'project_wrapper:clean'
]

task :clobber => [
	'oF:clean',
	'core_wrapper:clobber',
	'project_wrapper:clobber'
]

# =============
# old stuff

# task :clobber => ['oF_deps:clobber', 'oF:clean']

# TODO: Update clean tasks to remove the makefile after running "make clean"
# (the main Makefile is removed on 'clean', so I think all other auto-generated makefiles should follow suit)

# =============










# 	rake oF:clean
# 		rake oF_deps:clean
# 			rake oF_deps:kiss:clean
# 			rake oF_deps:tess2:clean
	
# # clobber
# 	rake clobber
	
# 	rake oF_deps:clobber
# 		rake oF_deps:kiss:clobber
# 		rake oF_deps:tess2:clobber
	
# 	rake cpp_project:clobber[rubyOF_project]
	
# 	rake cpp_callbacks:clobber[rubyOF_project]




load './rake/examine.rake'
