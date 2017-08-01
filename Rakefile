require 'rake/testtask'
require 'rake/clean'

require 'fileutils'
require 'open3'
require 'yaml' # used for config files
require 'json' # used to parse Clang DB


require './common'
# ^ this file declares GEM_ROOT constant, other constants, and a some functions

# invoke a particular rake task by name (and then allow it to be run again later)
def run_task(task, rake_args=nil)
	Rake::Task[task].reenable
	Rake::Task[task].invoke(*rake_args) # Splat is legal on nil
	# Rake::Task[task].reenable
	
	# Original from here
	# src: http://stackoverflow.com/questions/577944/how-to-run-rake-tasks-from-within-rake-tasks
	# (slight modifications have been made)
end


# temporarily swap out the makefile for an alternate version
# 
# main_filepath, alt_filepath:  Paths to main and alt makefile, relative to common_root.
# common_root:                  As above.
# work_dir:                     Path under which to run the commands specified in the block.
def swap_makefile(common_root, main_filepath, alt_filepath, &block)
	swap_ext = ".temp"
	swap_filepath = File.join(common_root, "Makefile#{swap_ext}")
	
	
	main_filepath = File.expand_path(File.join(common_root, main_filepath))
	alt_filepath  = File.expand_path(File.join(common_root, alt_filepath))
	
	
	
	
	# run tasks associated with the alternate file
	begin
		FileUtils.mv main_filepath, swap_filepath # rename main makefile
		FileUtils.cp alt_filepath, main_filepath  # switch to .a-creating mkfile
		
		block.call
	ensure
		FileUtils.cp swap_filepath, main_filepath # restore temp
		FileUtils.rm swap_filepath                # delete temp		
		# I think this ensure block should make it so the Makefile always restores,
		# even if there is an error in the block.
		# src: http://stackoverflow.com/questions/2191632/begin-rescue-and-ensure-in-ruby
	end
end


# ==== rake argument documentation ====
# :rubyOF_project		name of project (if under project directory)
#                         OR
#                    full path to project (if stored elsewhere)
# =====================================






# generate depend file for gcc dependencies
# sh "gcc -MM *.c > depend"





# use 'rake clean' and 'rake clobber' to
# easily delete generated files


CLEAN.include(OF_RAW_BUILD_VARIABLE_FILE)
CLEAN.include(OF_BUILD_VARIABLE_FILE)

# NOTE: Clean / clobber tasks may accidentally clobber oF dependencies if you are not careful.
CLEAN.include('ext/rubyOF/Makefile')
CLEAN.include('ext/**/*{.o,.log,.so}')
CLEAN.include('ext/**/*{.a}')
	# c1 = CLEAN.clone
	# p CLEAN
CLEAN.exclude('ext/openFrameworks/**/*')
CLEAN.exclude('ext/oF_deps/**/*')
# ^ remove the openFrameworks core
	# c2 = CLEAN.clone
	# p CLEAN
# CLEAN.exclude('ext/oF_apps/**/*')
# # ^ remove the test apps as well



# Clean up clang file index as well
# (build from inspection of 'make' as it builds the c-library)
CLEAN.include(CLANG_SYMBOL_FILE)





CLOBBER.include('bin/lib/*.so')
CLOBBER.include('lib/**/*.so')
CLOBBER.exclude('ext/openFrameworks/**/*')
CLOBBER.exclude('ext/oF_deps/**/*')





	# c3 = CLOBBER.clone
	# p CLOBBER
# CLOBBER.include('lib/**/*.gem') # fix this up. I do want to clobber the gem tho

	# require 'irb'
	# binding.irb

	# exit
	# raise "WHOOPS"






namespace :oF do
	desc "Download openFrameworks libraries (build deps)"
	task :download_libs do
		run_i "ext/openFrameworks/scripts/linux/download_libs.sh"
		# ^ this script basically just triggers another script:
		#   ext/openFrameworks/scripts/dev/download_libs.sh
	end
	
	# NOTE: If there is a problem with the core, try downloading libs again.
	# NOTE: If there is a problem with building the oF project, download libs again, build the core again, and then rebuild the project.
	desc "Build openFrameworks core (ubuntu)."
	task :build do
		puts "=== Building OpenFrameworks core..."
		Dir.chdir "./ext/openFrameworks/scripts/linux/" do
			run_i "./compileOF.sh -j#{NUMBER_OF_CORES}"
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
		run_task('base:clean')
		run_task('base:build')
	end
	
	
	
	
	
	desc "Build the project generator."
	task :compilePG => :build do
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
		dir = "ext/openFrameworks/apps/projectGenerator/commandLine/bin"
		full_dir = File.expand_path dir, GEM_ROOT
		
		
		a = File.join(GEM_ROOT, "ext", "openFrameworks")
		b = File.join(GEM_ROOT, "ext", "oF_apps", project)
		
		Dir.chdir full_dir do
			# p Dir.pwd
			
			run_i "./projectGenerator -o\"#{a}\" #{b}" 
		end
		
	end
	
end


# NOTE: Build deps under the oF_deps folder, and then copy over the results
namespace :oF_deps do
	# ===== Setup Custom OpenFrameworks Dependencies =====
	
	# declare configuration
	oF_lib_path  = File.join GEM_ROOT, "ext/openFrameworks/libs/"
	default_libs = File.join GEM_ROOT, "ext/oF_deps/master/original/"
	custom_libs  = File.join GEM_ROOT, "ext/oF_deps/master/custom/"
	
	# declare helper functions
	foo = ->(dir){
		Dir[dir + "*"]
		.collect{  |x| x.sub dir, ""  }
		.reject{   |x| x.downcase.include? "readme"  }
	}
	
	remove_libs = ->(output_dir, source_dir){
		Dir.chdir output_dir do
			foo[source_dir].each{  |name|  FileUtils.rm_rf name  }
		end
	}
	
	replace_libs = ->(output_dir, source_dir){
		Dir.chdir output_dir do
			foo[source_dir].each do |name|
				full_path = File.join(source_dir, name)
				
				FileUtils.copy_entry full_path, "./#{name}", true
				# copy_entry(src, dest, preserve = false, dereference_root = false, remove_destination = false)
			end
		end
	}
	
	desc "Use custom libs compiled with -fPIC for Ruby compatability."
	task :inject => [
		"kiss:package",
		"tess2:package"
	] do
		unless foo[default_libs] == foo[custom_libs]
			raise "ERROR: libraries in '#{default_libs}' not the same as those in '#{custom_libs}'"
		end
		
		puts "Injecting custom libs..."
		
		# remove default libs
		remove_libs[oF_lib_path, default_libs]
		
		# copy over new libs
		replace_libs[oF_lib_path, custom_libs]
		
		# remove the "repo" directory under the copy of the custom libs
		# (keep only the built packages, discard the source)
		# (the source will still be stored elsewhere anyway)
		["kiss", "tess2"].each do |name|
			Dir.chdir File.join(oF_lib_path, name) do
				FileUtils.rm_rf "./repo"
				FileUtils.rm_rf "./custom_build"
			end
		end
		
		puts "Done!"
	end
	
	desc "Undo inject_custom_libs (return to default libs)"
	task :revert do
		unless foo[default_libs] == foo[custom_libs]
			raise "ERROR: libraries in '#{default_libs}' not the same as those in '#{custom_libs}'"
		end
		
		puts "Reverting OpenFrameworks core libs..."
		
		# remove injected libs
		remove_libs[oF_lib_path, custom_libs]
		
		# restore default libs
		replace_libs[oF_lib_path, default_libs]
		
		puts "Done!"
	end
	
	
	
	# ====================================================
	
	
	desc "Clean all custom deps"
	task :clean => ['kiss:clean', 'tess2:clean']
	
	desc "Clobber all custom deps"
	task :clobber => ['kiss:clobber', 'tess2:clobber']
	
	
	# ====================================================
	
	
	
	
	namespace :kiss do
		# NOTE: Some of this path information is repeated above in the tasks that move the custom libraries into the oF build system.
		basedir = 'ext/oF_deps/master/custom/kiss/'
		subdir  = 'custom_build/'
		
		
		# NOTE: This build process currently only guaranteed to work with 64-bit linux. Uses the openframeworks apothecary build process, ammended to add the -fPIC flag.
		# desc "testing"
		task :build do
			Dir.chdir File.join(GEM_ROOT, basedir, subdir) do
				p Dir.pwd
				FileUtils.mkdir_p "./lib/"
				run_i "make"
			end
		end
		
		# desc "Move files to mimic what oF expects."
		task :package => :build do
			puts "Packaging kisstff..."
			
			Dir.chdir File.join(GEM_ROOT, basedir) do
				# kiss_fft.h
				# kiss_fftr.h
				# # => include/
				FileUtils.mkdir_p "./include"
				FileUtils.cp(
					"./repo/kiss_fft.h",
					"./include/kiss_fft.h",
				)
				FileUtils.cp(
					"./repo/tools/kiss_fftr.h",
					"./include/kiss_fftr.h",
				)
				
				# COPYING
				# # => license/
				FileUtils.mkdir_p "./license"
				FileUtils.cp(
					"./repo/COPYING",
					"./license/COPYING",
				)
				
				# libkiss.a
				# => lib/linux64/
				output_dir = "./lib/#{PLATFORM}/"
				FileUtils.mkdir_p output_dir
				FileUtils.cp(
					"./custom_build/lib/libkiss.a",
					File.join(output_dir, "libkiss.a")
				)
				
			end
		end
		
		# desc "testing"
		task :clean do
			Dir.chdir File.join(GEM_ROOT, basedir, subdir) do
				run_i "make clean"
			end
		end
		
		# desc "testing"
		task :clobber => :clean do
			path = File.join(GEM_ROOT, basedir, subdir, "libkiss.a")
			if File.exists? path
				FileUtils.rm path
			end
			
			FileUtils.rm_rf File.join(GEM_ROOT, basedir, subdir, "lib")
			FileUtils.rm_rf File.join(GEM_ROOT, basedir, "lib")
			
			Dir.chdir File.join(GEM_ROOT, basedir, subdir) do
			end
		end
	end
	
	namespace :tess2 do
		# NOTE: Some of this path information is repeated above in the tasks that move the custom libraries into the oF build system.
		basedir = 'ext/oF_deps/master/custom/tess2/'
		subdir  = 'repo/'
		
		# src: https://github.com/memononen/libtess2
		
		# NOTE: assumes that premake is installed
			# sudo apt-get install premake4
		# NOTE: changes to the patch procedure in this file will force a rebuild
			# (other non-related changes to Rakefile will also force a rebuild)
		# desc "testing"
		task :build => [__FILE__] do
			Dir.chdir File.join(GEM_ROOT, basedir, subdir) do
				p Dir.pwd
				
				# run premake (generate GNU makefile system)
				run_i "premake4 gmake"
				
				# patch files (add the -fPIC flag)
				filepath = "./Build/tess2.make"
				lines = File.readlines(filepath)
				
					puts "Patching tess2 makefile..."
					target_string = "CFLAGS    +="
					lines
					.select{  |line| line.include? target_string  }
					.each do  |line|
						line.sub! "\n", " -fPIC\n"
						puts line
					end
				
				File.open(filepath, "w") do |f|
					f.write lines.join('')
				end
				
				# build
				Dir.chdir "Build" do 
					run_i "make"
				end
			end
		end
		
		# desc "Move files to mimic what oF expects."
		task :package => :build do
			puts "Packaging tess2..."
			
			Dir.chdir File.join(GEM_ROOT, basedir) do
				# Include/tesselator.h
				# # => include/
				FileUtils.mkdir_p "./include"
				FileUtils.cp(
					"./repo/Include/tesselator.h",
					"./include/tesselator.h",
				)
				
				# LICENSE.txt
				# # => license/
				FileUtils.mkdir_p "./license"
				FileUtils.cp(
					"./repo/LICENSE.txt",
					"./license/LICENSE.txt",
				)
				
				# Build/libtess2.a
				# # => lib/linux64/libtess2.a
				output_dir = "./lib/#{PLATFORM}/"
				FileUtils.mkdir_p output_dir
				FileUtils.cp(
					"./repo/Build/libtess2.a",
					File.join(output_dir, "libtess2.a")
				)
				
			end
		end
		
		# desc "testing"
		task :clean do
			Dir.chdir File.join(GEM_ROOT, basedir, subdir) do
				if Dir.exists? "Build"
					Dir.chdir "Build" do 
						run_i "make clean"
					end
				end
			end
		end
		
		# desc "testing"
		task :clobber do
			Dir.chdir File.join(GEM_ROOT, basedir, subdir) do
				FileUtils.rm_rf "Build"
			end
		end
	end
end


namespace :oF_project do
	desc "Debug with gdb"
	task :debug do
		Dir.chdir OF_SKETCH_ROOT do
			puts "Remember: type 'q' to exit GDB."
			puts "=============================="
			puts ""
			Kernel.exec "gdb ./bin/#{OF_SKETCH_NAME}_debug"
		end
	end
	
	desc "Run just the C++ components for the oF sketch"
	task :run do
		Dir.chdir OF_SKETCH_ROOT do
			run_i "make Run#{TARGET}"
		end
	end
	
	# NOTE: building the project requires the core to be built correctly.
	desc "Build the oF project (C++ only) - generates .o files"
	task :build do # implicity requires 'oF:build' task
		puts "=== Building oF project..."
		Dir.chdir OF_SKETCH_ROOT do
			# Make the debug build if the flag is set,
			# othwise, make the release build.
			debug = OF_DEBUG ? "Debug" : ""
			
			
			begin
				run_i "make #{debug} -j#{NUMBER_OF_CORES}"
			rescue StandardError => e
				puts "ERROR: Could not build oF sketch."
				exit
			end
			# FileUtils.touch 'oF_project_build_timestamp'
		end
	end
	
	
	# desc "Update the timestamp by rebuilding the project."
	# file File.join(OF_SKETCH_ROOT, 'oF_project_build_timestamp') => :build
	
	
	desc "Clean the oF project (C++ only) [also cleans addons]"
	task :clean do
		Dir.chdir OF_SKETCH_ROOT do
			run_i "make clean"
		end
	end
	
	
	
	# rebuilding the project should rebuild the addons too
	desc "Rebuld the project."
	task :rebuild do
		run_task('oF_sketch:clean')
		run_task('oF_sketch:build')
	end
	
	
	
	
	# show the .o files generated that are specific to this project
	# (these are the files used to generate the static lib)
	desc "DEBUG: show the .o files generated that are specific to this project"
	task :examine do
		Dir.chdir OF_SKETCH_BUILT_DIR do
			puts "local oF build directory:"
			puts Dir.pwd
			p Dir['./*']
		end
	end
	
	
	
	
	
	# actually generates two files:
	# + oF_build_variables.yaml (aka OF_BUILD_VARIABLE_FILE)
	# + raw_oF_variables.yaml   (intermediate representation of raw data)
	file OF_BUILD_VARIABLE_FILE => 
	[
		# # NOTE: slight indirection here - depend on timestamp file instead of build task directly, so that 
		# File.join(OF_SKETCH_ROOT, 'oF_project_build_timestamp'),
		File.expand_path("./Makefile.static_lib", OF_SKETCH_ROOT),
		File.expand_path("./addons.make",         OF_SKETCH_ROOT),
		__FILE__, # if the Rake task changes, then update the output file
		COMMON_CONFIG # if config variables change, then build may be different
	] do
		puts "=== Exporting oF project build variables..."
		
		swap_makefile(OF_SKETCH_ROOT, "Makefile", "Makefile.static_lib") do
			Dir.chdir OF_SKETCH_ROOT do
				# run_i "make printvars"
				
				out = `make printvars TARGET_NAME=#{TARGET}`
				# p out
				
				out = out.each_line.to_a
				
				
				File.open(OF_RAW_BUILD_VARIABLE_FILE, "w") do |f|
					f.puts out.to_yaml
				end
				
				
				final = 
					out.select{  |line|
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
				
				
				
				filepath = OF_BUILD_VARIABLE_FILE
				File.open(filepath, "w") do |f|
					f.puts final.to_yaml
				end
				
				puts "=> Variables written to '#{filepath}'"
				puts ""
			end
		end
	end
	
	desc "Export build variables from oF build system (linux)."
	task :export_build_variables => OF_BUILD_VARIABLE_FILE
	
	
	desc "Drop to IRB to explore oF build system variables."
	task :explore => :export_build_variables do
		of_build_variables = YAML.load_file(OF_BUILD_VARIABLE_FILE)
		
		require 'irb'
		binding.irb
	end
	
	
	
	namespace :static_lib do
		# use a modified version of the oF build system
		# to generate a C++ static lib
		# (same make file used to generate OF_BUILD_VARIABLE_FILE)
		
		
		# outputs OF_SKETCH_LIB_FILE
		# but don't want to write this as a file task,
		# because I want the makefile to determine if things should be rebuilt or not
		desc "generate static lib from oF project"
		task :build do
			puts "=== Making oF sketch into a static library..."
			swap_makefile(OF_SKETCH_ROOT, "Makefile", "Makefile.static_lib") do
				Dir.chdir OF_SKETCH_ROOT do
					begin
						run_i "make static_lib TARGET_NAME=#{TARGET}"
					rescue StandardError => e
						puts "ERROR: Could not make a static library out of the oF sketch project."
						exit
					end
				end
			end
			
			
			
			
			# TODO: update this task so it actually works correctly.
			# Often, it fails to rebuild the archive correctly, which invaldates steps further down the chain
			# (or at least that's what this looks like)
			# (i'm not actually sure, but it's super confusing why old symbols are cropping up in my final Ruby executable.)
			
			# NOTE: could potentially use the exported build variables file (the one whose primary use is in extconf.rb) in order to get the build variables, if you really need them. Seems like that might actually end up being better than doing the weird makefile switcheroo?
			# If you contain more of the work in the Rakefile, maybe rake will have a better idea of the dependency chain, and not have to remake stuff so much?
		end
		
		task :clean do
			swap_makefile(OF_SKETCH_ROOT, "Makefile", "Makefile.static_lib") do
				Dir.chdir OF_SKETCH_ROOT do
					run_i "make clean_static_lib TARGET_NAME=#{TARGET}"
				end
			end
		end
	end
	
end




# === Build the C extension
namespace :cpp_wrapper_code do
	# make the :test task depend on the shared
	# object, so it will be built automatically
	# before running the tests
	
	# rule to build the extension: this says
	# that the extension should be rebuilt
	# after any change to the files in ext
	
	c_library = "lib/#{NAME}/#{NAME}.so"
	# NOTE: This only works for linux, because it explicitly uses the ".so" extension
	
	
	
	# TODO: update source file list
	c_library_deps = Array.new
	# c_library_deps += Dir.glob("ext/#{NAME}/*{.rb,.c}")
	
	
	# Ruby / Rice CPP files
	c_library_deps += Dir.glob("ext/#{NAME}/**/*{.cpp,.h}")
	
	# 
	c_library_deps << "ext/#{NAME}/extconf.rb"
	c_library_deps << "ext/#{NAME}/extconf_common.rb"
	c_library_deps << "ext/#{NAME}/extconf_printer.rb"
	
	c_library_deps << __FILE__ # depends on this Rakefile
	
	# c_library_deps << OF_BUILD_VARIABLE_FILE
	# TODO: ^ re-enable this ASAP
	
	# NOTE: adding OF_BUILD_VARIABLE_FILE to the dependencies for the 'c_library' makes it so extconf.rb has to run every time, because the variable file is being regenerated every time.
	
	
	# FIXME: can't seem to just run rake again to rebuild. keep having to clobber, and then do a full clean build again.
	
	# Mimic RubyGems gem install procedure, for testing purposes.
	# * run extconf
	# * execute the resultant makefile
	# * move the .so to it's correct location
	file c_library => c_library_deps do
		Dir.chdir("ext/#{NAME}") do
			# this does essentially the same thing
			# as what RubyGems does
			puts "=== starting extconf..."
			
			begin
				run_i "ruby extconf.rb"
			rescue StandardError => e
				puts "ERROR: Could not configure c extension."
				exit
			end
			
			
			puts "======= Top level Rakefile"
			puts "=== configuration complete. building C extension"
			
			
			# Run make
			
			flags = ""
			# flags += " -j#{NUMBER_OF_CORES}" if Dir.exists? '/home/ravenskrag' # if running on my machine
			
			
			# ======================================
			# SPECIAL MOD
			# regenerate the clang DB if necessary
			if regenerate_clang_db? # see definition below
				puts "Building and regenerating clang DB"
				
				# need to recompile everything to get a proper DB
				# so go ahead and clean out everything
				run_i "make clean"
				
				# ok, now examine the build process and build the DB
				begin
					run_i "bear make #{flags}"
				rescue StandardError => e
					puts "ERROR: Could not build c extension and / or clang DB"
					exit
				end
				
				# Clang DB file is generated here,
				# but needs to be moved to the gem root to function
				FileUtils.mv "./compile_commands.json", CLANG_SYMBOL_FILE
				# => CLANG_SYMBOL_FILE
				
				# TODO: consider analying the app build as well, and then merging the two JSON documents together into a single clang DB
				
			else
				# run normally
				puts "Building..."
				begin
					run_i "make #{flags}"
				rescue StandardError => e
					puts "ERROR: Could not build c extension."
					exit
				end
			end
			# ======================================
		end
		
		# NOTE: This is part of a normal extconf build, but I don't want it.
		#       In the context of this build, this .so is only an intermediate.
		# puts "=== Moving dynamic library into correct location..."
		# FileUtils.cp "ext/#{NAME}/#{NAME}.so", "lib/#{NAME}"
		
		
		puts "=== C extension build complete!"
	end
	
	# HELPER METHOD for c extension generation (managed clang DB)
	# Number of known files on disk doesn't match up with the database.
	# Must regenerate the database.
	def regenerate_clang_db?
		if File.exists? CLANG_SYMBOL_FILE
			# check the contents of the DB to find out
			data     = File.read(CLANG_SYMBOL_FILE)
			clang_db = JSON.parse(data)
			
			directory        = File.join GEM_ROOT, "ext/#{NAME}"
			cpp_source_files = Dir[File.join(directory, '*{.cpp}')]
			
			
			return clang_db.length != cpp_source_files.length
		else
			# don't bother: you need to generate the DB
			return true
		end
	end
	
	
	
	
	# NOTE: This is a shortcut for the file task above.
	desc "Build the C extension (core Rice glue code)"
	task :build => c_library do
		# FileUtils.rm c_library
		# Just want the intermediates from the build process
		# the actual final dynamic library should be discarded.
		# This is because this is not the true final output.
		# The final output can only be made when these intermediates
		# are combined with the intermediates of the project-specific C++ build.
		
		# NO.
		# Need to check against this library to make sure final link works.
		# As such, you can't delete this .so
	end
	
	
	# Not sure how often you want to regenerate this file, but not every time you build.
	# You need to run make and have something happen. If nothing gets build from the makefile, the clang database will end up empty.
	
	
	
	# TODO: make sure the clang symbols are generated as part of the standard build process
	# TODO: add clang symbols file to the .gitignore. Should be able to generate this, instead of saving it.
	
	
	
	# Anything cleaned up here should already be
	# caught by the main clean task rules.
	# Only call this task if you need to clean
	# just the few things from this build phase.
	task :clean do
		Dir.chdir("ext/#{NAME}") do
			run_i "make clean"
		end
	end
end










module RubyOF
	module Build

class << self
	
	# parse_project_path(1), with error checking
	# based on the assumption that you're trying
	# to access a project that already exists.
	# 
	# (even if there is currently no error checking,
	# please use this version for semantic reasons)
	def load_project(path_or_name)
		name, path = parse_project_path(path_or_name)
		
		# === Error checking for 'project_name' and 'project_path'
		# TODO: what happens when a project name is specified, but no such project exists?
		# -----
		# ensure project actually exists
		if Dir.exists? path
			
		else
			raise "ERROR: RubyOF Project '#{name}'' not found. Check your spelling, or use full paths for projects not under the main directory."
		end
		
		# -----
		
		
		return name, path
	end
	
	
	
	
	# parse_project_path(1), with error checking
	# based on the assumption that you're trying
	# to create a new project.
	# 
	# (even if there is currently no error checking,
	# please use this version for semantic reasons)
	# 
	# 
	# Doesn't actually create anything.
	# The specifics of creation should be handled in the block.
	def create_project(path_or_name, &block)
		name, path = parse_project_path(path_or_name)
		
		# == Bail out if the path you are trying to create already exists
		if Dir.exists? path
			raise "ERROR: Tried to create new RubyOF project @ '#{path}', but directory already exists."
		end
		
		
		begin
			block.call path
		rescue Exception => e
			# If target directory was created, revert that change on exception
			
			if Dir.exists? path
				FileUtils.rm_rf path 
				puts "Exception detected in RubyOF::Build.create_project(). Restoring stable state."
			end
			
			raise e
		end
		
		return nil
	end
	
	
	
	private
	
	
	# TODO: allow either project name or full path to project as argument
	# (if full path detected, need to set @project_name and @project_path)

	# input  (1): 
	#     path_or_name = Either a full path to the folder, or a project name
	#                    If given only the project name, assume that
	#                    the full path is located under [GEM_ROOT]/bin/projects/
	# output (2): [project_name, project_path]
	# example output:
	#     project_name = "example"                        (just the dir name)
	#     project_path =  [GEM_ROOT]/bin/projects/example (full path to dir)
	def parse_project_path(path_or_name)
		# name of the project
		# (should be the same as the directory name)
		project_name = path_or_name
		
		# root of the project
		project_path   = File.join(
			GEM_ROOT, 'bin', 'projects', project_name
		)
		
		
		
		# TODO: distinguish between creating a new project, and accessing an existing one.
			# When accessing and existing project,
			# you need to check to make sure that
			# project actually exists. But if you
			# check for existance when making a
			# new project, you will *always* fail.
		
		
		
		return project_name, project_path
	end
	
end


end
end










module Monad
	class << self
		# maybe monad that understand Ruby has exceptions
		# contex: object to call the methods on
		# list:   lisp-style list of functions (nested list)
		#         eg) [[:foo, "hello", 2,3], [:baz, "world", 4,5, false]]
		def maybe_e(context, list)
			list.each_with_index do |fx, i|
				begin
					context.send *fx
				rescue => e
					puts "ERROR: Exception on function @ index #{i} in Maybe monad."
					puts "=>     #{list[i]}"
					raise e
					
					# break
				end
			end
		end
	end
end


module RubyOF
	module Build

class ExtensionBuilder	
	def initialize(project_name)
		raise "ERROR: no project name specified" if project_name.nil?
		# ^ Need to do this, because of how Rake tasks work
		#   It is always possible to call a rake task that requires arguments
		#   with no arguments at all.
		# But the exception handling needs to be here,
		# because the constructor is called in many tasks.
		# (code duplication would be a hassle...)
		
		name, path = RubyOF::Build.load_project(project_name)
		# name of the project
		# (should be the same as the directory name)
		@project_name = name
		
		# root directory for the project
		@project_path = path
		
		
		
		# path to most of the .o files generated by core extension build
		@core_path = File.join(GEM_ROOT, 'ext', NAME)
		
		# path to the app.o (generated for this RubyOF project)
		@app_path  = File.join(@project_path, 'ext', 'window')
		
		
		
		# 'extconf_variables.yaml' files
		# (build system variable dumps)
		@main_build_var_file = File.join(
			GEM_ROOT, 'ext', NAME, 'extconf_variables.yaml'
		)
		
		@project_build_var_file = File.join(
			@app_path, 'extconf_variables.yaml'
		)
		
		
		
		# where do the data files for the project go?
		@data_path      = File.join(
			@project_path, 'bin', 'data'
		)
		
		# where is the data path constant defined?
		# (C++ header. #defines constant for oF at C++ level)
		# [this file is automatically generated by the rakefile build system]
		@data_path_file = File.join(
			@app_path, 'constants', 'data_path.h'
		)
		
		
		
		
		
		@so_paths = {
			# :wrapper = core Rice wrapper code
			# :project = intermediate .so for project-specific code
			# :final   = output .so that combines both :wrapper and :project
			:wrapper => File.join(GEM_ROOT, 'ext', NAME, "#{NAME}.so"),
			:project => File.join(@app_path, "#{NAME}.so"),
			:final   => File.join(@app_path, 'final', "#{NAME}.so"),
			
			
			# The final output goes here,
			# to be loaded by the Ruby interpreter
			:install => File.join(GEM_ROOT, 'lib', NAME, "#{NAME}.so")
		}
	# NOTE: The wrapper build, project build, and final link can all live in harmory. No build phase will clobber any parts needed by other phase.
		
	end
	
	# ------------------------
	
	
	
	
	# patch c constant file with proper data path
	# 
	# deps: @data_path_file    (variable)
	#       @data_path         (variable)
	def create_data_path_file
		# NOTE: only need to run this method when @data_path is changed
		puts "=== create file"
		
		FileUtils.mkdir_p File.dirname @data_path_file
		
		File.open(@data_path_file, 'w') do |f|
			f.puts "#define DATA_PATH \"#{@data_path}\""
		end
	end
	
	
	# # NOTE: generates project-specific 'app.o' file
	# desc "build RubyOF project-specific C++ code (linux)"
	def build
		puts "=== build"
		
		# check if the 
		# is newer than
		# the intermidate .so from the main build
			# "ext/#{NAME}/#{NAME}.so"
		
		
		
		puts "Building project-specific C++ code..."
		Dir.chdir(@app_path) do
			puts "=== Generating makefile for project '#{@project_name}'"
			run_i "ruby extconf.rb"
			# ^ dumps log of variables to @project_build_var_file
			
			puts "=== Building project..."
			run_i "make"
			# ^ creates .so @ this location => @so_paths[:project]
		end
	end
	
	# desc "link final dynamic library (linux)"
	#   Combines obj files from Rice wrapper build
	#   and obj files from project-specific build
	#   into one cohesive whole
	# 
	# ASSUME: main extconf.rb and project-specific extconf.rb have run, and have succesfully outputed their variable files.
	# NOTE: Only need to run this if 'build' has changed some files
	def link
		puts "=== Linking final dynamic library..."
		
		# === Create a place for the final .so to go
		# Need to have a copy somewhere other than the install location
		# because other projects may need to move into that space.
		FileUtils.mkdir_p  File.dirname @so_paths[:final]
		
		
		# === Load in environment variables
		puts "loading main extconf variables..."
		main_vars = load_extconf_data(@main_build_var_file)
		
		puts "loading #{NAME} project extconf variables..."
		project_vars = load_extconf_data(@project_build_var_file)
		
		
		# === Expand obj paths to full paths
		main_objs = 
			main_vars['$objs'].collect{ |x|
				File.join(@core_path, x)
			}
		
		
		# === Mix in obj paths from the project
		app_objs = 
			project_vars['$objs'].collect{ |x|
				File.join(@app_path, x)
			}
		
		
		# NOTE: The extconf.rb build files constantly relink the .so files, so their timestamps are not a reliable indicator of when the last build occurred. You must observe the time on the .o files instead.
		timestamps = 
			(main_objs + app_objs).collect{ |x|
				Pathname.new(x)
			}.collect{ |path|
				path.mtime # get last modification time for file
			}.sort # chronological order (oldest first)
		puts "Printing dependency timestamps..."
		p timestamps
		# NOTE: older < newer
		
		
		
		
		# only perform the link when the component obj files have been updated
		# (one or more .o files are newer than the .so file)
		# [aka, skip linking when .so is newer than the newest .o file]
		so_location = Pathname.new(@so_paths[:final])
		p so_location.mtime if so_location.exist?
		
		if so_location.exist? and timestamps.last < so_location.mtime
			puts "skipping link phase"
			return
			# use 'return' instead of 'raise' to continue the build
		end
		
		
		Dir.chdir(@app_path) do
			# TODO: need to allow linking of additional stuff as well (any additional flags that might be set by the RubyOF project specific build)
			# TOOD: Figure out if the flags used by the app are always a superset of the flags used by main (may not be a proper superset)
			
			
			
			# === Assemble the base link command
			puts "reading gem environment..."
			env = read_gem_env()
			
			# --- Extract exec_prefix from ruby environment data
			# 'exec_prefix' is the directory that contains 'bin/ruby'
			# As such, you just need to step up two levels in the filesystem.
			exec_prefix =  File.expand_path '../..', env["RUBY EXECUTABLE"]
			lib_dir = "#{exec_prefix}/lib"
			
			
			final_link_command = 
				[
					main_vars['$LDSHARED_CXX'],
					'-o', # have to supply this manually
					"./final/#{NAME}.so",
					app_objs,
					main_objs,
					"-L. -L#{lib_dir} -Wl,-R#{lib_dir}",
					main_vars['$LDFLAGS'],
					main_vars['$DLDFLAGS'],
					main_vars['$libs'],
					main_vars['$LIBRUBYARG'],
					main_vars['$LIBS']
				].join(' ')
			
			
			
			# === Makefile variable replacement
			# just blank out ${ORIGIN}
			# That seems to be what the original extconf.rb build did.
			final_link_command.gsub! "${ORIGIN}", ''
			
			
			
			# === Display link command in terminal
			# (substitute [GEM_ROOT] for the root path, like in 'run_i')
			# (substitution is for display purposes only)
			puts "Performing final link..."
			puts final_link_command.gsub GEM_ROOT, '[GEM_ROOT]'
			
			
			# === Execute the final link
			run_i final_link_command
		end
		
		
		
		puts "Final link complete!"
	end
	
	private
	
	def load_extconf_data(path_to_yaml_dump)
		extconf_data = YAML.load_file(path_to_yaml_dump)
		extconf_variable_names, extconf_variable_hash = extconf_data
		
		return extconf_variable_hash
	end
	
	# Turns out, the output of the command 'gem env' is basically YAML.
	# As such, you can load that right up as a string,
	# in order to get information about the enviornemnt.
	def read_gem_env
		# --- Gotta do a little bit of reformatting of this data...
			# Top level data structure is an Array of Hash objects.
			# "flatten" it out, merging all hashes together,
			# and removing the containing Array.
		env = YAML.load `gem env`
		env = 
			env["RubyGems Environment"]
			.inject(Hash.new){ |hash, x|
				hash.merge! x
			}
		# p env
		
		return env
	end
	
	public
	
	
	
	
	
	def run_tests
		puts "=== running tests"
		
		symbols = self.methods.grep /test_/
		p symbols
		
		symbols.each do |sym|
			self.send sym
		end
	end
	
		# Check final dynamic libary for symbols that will only exist
		# when the final link is performed correctly.
		# desc "make sure final link works as expected (linux)"
		def test_final_link
			puts "--- testing: make sure final link has happened"
			
			# The test symbol sholud be something that only exists
			# in the base build, and not the project build.
			# Thus, the presense of this symbol in the final linked product
			# confirms that the link has succeded.
			
			
			# --- first, make sure the baseline lib actually exists
			#     (can't compare with something that's not there)
			path = Pathname.new(@so_paths[:wrapper])
			unless path.exist?
				raise "ERROR: Baseline lib not found @ #{path}"
			end
			
			
			# --- check the output location too
			path = Pathname.new(@so_paths[:final])
			unless path.exist?
				raise "ERROR: Dynamic lib from final link not found @ #{path}"
			end
			
			
			# --- perform the main checks
			sym      = "Launcher"
			test_cmd = "nm -C #{NAME}.so  | grep #{sym}"
			
			# baseline
			cmd1 = nil
			Dir.chdir(File.dirname(@so_paths[:wrapper])) do
				cmd1 = `#{test_cmd}` # run test command in shell
			end
			
			# final link
			cmd2 = nil
			Dir.chdir(File.dirname(@so_paths[:final])) do
				cmd2 = `#{test_cmd}` # run test command in shell
			end
			
			
			# p cmd1
			# p cmd2
			if cmd1.nil? or cmd2.nil?
				raise "ERROR: unexpected problem while inspecting final product."
			elsif cmd1 == ''
				raise "ERROR: symbol '#{sym}' not present in baseline lib."
			elsif cmd2 == '' # at this point, no error for baseline lib
				raise "ERROR: final .so did not contain symbol '#{sym}' as expected"
			else
				puts "no problems with final link"
			end
		end
		
		# Check if symbol is undefined, rather than merely if it is present.
		# desc "Make sure app factory has been linked into final product (linux)"
		def test_app_factory_link
			puts "--- testing: looking for 'app factory' symbol"
	
			sym      = "appFactory_create"
			test_cmd = "nm -C #{NAME}.so  | grep #{sym}"
			
			
			out = nil
			
			Dir.chdir(File.dirname(@so_paths[:final])) do
				out = `#{test_cmd}`
			end
			
			
			
			
			if out.nil?
				raise "ERROR: unexpected problem while inspecting final product."
			elsif out == ''
				raise "ERROR: symbol '#{sym}' not found in final dynamic library"
			elsif out.include? 'U'
				# ex)  U appFactory_create(Rice::Object)
				raise "ERROR: symbol '#{sym}' found, but was undefined"
			else
				# No problems!
				puts "no problems - appFactory linked correctly"
			end
		end
	
	
	
	# desc "move completed dynamic library to final location (linux)"
	# task :install do
	def install
		puts "=== install"
		
		
		puts "Moving completed dynamic library to final location"
		# copy dynamic lib into final location
		FileUtils.cp(@so_paths[:final], @so_paths[:install])
	end
	
	
	
	
	# ------------------------
	
	def main
		Monad.maybe_e self, [
			[:create_data_path_file],
			[:build],
			[:link],
			[:run_tests],
			[:install],
		]
	end
	
	def clean
		Dir.chdir(@app_path) do
			begin 
				run_i "make clean"
			rescue StandardError => e
				# FIXME: Can't seem to catch, suppress, and continue
				puts "nothing to clean for #{@app_path}"
			end
		end
		
		# clean files
		[
			@project_build_var_file,
			@data_path_file,
			@so_paths[:final],
			# @so_paths[:project], # should already be cleaned by 'make clean'
		].each do |filepath|
			FileUtils.rm filepath if File.exists? filepath
		end
		
		# clean directories
		[
			File.dirname(@data_path_file),
			File.dirname(@so_paths[:final])
		].each do |filepath|
			FileUtils.rm_rf filepath if Dir.exists? filepath
		end
	end
	
	def clobber
		self.clean
		
		# clobber files
		[
			@so_paths[:install],
			File.join(@app_path, "Makefile")
		].each do |file_to_be_cleaned|
			FileUtils.rm file_to_be_cleaned if File.exist? file_to_be_cleaned
		end
	end
	
end


end
end

namespace :cpp_project do
	
	task :build, [:rubyOF_project] do |t, args|
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
		@project_name
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
			Kernel.exec "ruby #{exe_path}"
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


desc "Generate RubyOF project by copying the 'boilerplate' project"
task :project_generator, [:rubyOF_project] do |t, args|
	
	# == Figure where to place the new project
	path_or_name = args[:rubyOF_project]
	RubyOF::Build.create_project(path_or_name) do |path|
		# == Copy the template project into the target location
		template_project_name = 'boilerplate'
		
		# Need to clean the example first, so you don't copy built files
		run_task('clean_project', template_project_name)
		
		# Find full path to template
		# NOTE: template_name == template_project_name
		template_name, template_path =
			RubyOF::Build.load_project(template_project_name)
		
		# Copy the full directory to destination
		FileUtils.cp_r template_path, path
	end
	
	
	
	
	# # NOTE: This is the job for a unit test. Don't test this here
	# # The name inputted should be exactly the same as the name outputted.
	# # If not, there is a problem with the parsing function.
	# if template_project_name != template_name
	# 	raise "ERROR: RubyOF::Build.create_project() parsed incorrectly." +
	# 	      " Given '#{template_project_name}' "
	# end;
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
	FileUtils.mkdir_p "bin/projects"
	FileUtils.mkdir_p "bin/projects/testProjectRuby/bin"
	FileUtils.mkdir_p "bin/projects/testProjectRuby/ext"
	FileUtils.mkdir_p "bin/projects/testProjectRuby/lib"
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
	'oF:build',
	
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
	
	
	'cpp_project:build',
	'cpp_callbacks:build'
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
	'oF_project:build',                  # implicitly requires oF:build
	'oF_project:export_build_variables', # implicitly requires oF_project:build
	'oF_project:static_lib:build',
	
	:install_oF_dynamic_libs,
	
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
desc "Run default build task (:build_project)"
task :build, [:rubyOF_project] => :build_project



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





# TODO: move this into the oF_deps namespace, and then consolodate all path definitions.
# NOTE: Assumes you're running on Linux
desc "Examine compiled libraries (linux)"
task :examine, [:library_name] do |t, args|
	name = args[:library_name].to_sym
	path =
		case name
			when :kiss
				"ext/oF_deps/master/custom/kiss/custom_build/lib/libkiss.a"
			when :tess2
				"ext/oF_deps/master/custom/tess2/lib/#{PLATFORM}/libtess2.a"
			when :oF_core
				"ext/openFrameworks/libs/openFrameworksCompiled/lib/linux64/libopenFrameworks.a"
			when :oF_project
				if OF_DEBUG
					"ext/oF_apps/#{OF_SKETCH_NAME}/bin/#{OF_SKETCH_NAME}_debug"
				else
					"ext/oF_apps/#{OF_SKETCH_NAME}/bin/#{OF_SKETCH_NAME}"
				end
			when :oF_project_lib
				"ext/oF_apps/#{OF_SKETCH_NAME}/lib/libOFSketch.a"
			when :rubyOF
				"ext/rubyOF/rubyOF.so"
		end
	
	case File.extname path
		when ".a"
			run_i "nm -C #{path}"
		when ".so"
			run_i "nm -C -D #{path}"
		else # linux executable
			run_i "nm -C #{path}"
	end
	
	# # the -C flag is for de-mangling the C++ function names
	# run_i "nm -C #{path_to_lib}"
	
	# # this command will let you see inside an .so
	# # nm -C -D libfmodex.so
	# # src: http://stackoverflow.com/questions/4514745/how-do-i-view-the-list-of-functions-a-linux-shared-library-is-exporting
end

