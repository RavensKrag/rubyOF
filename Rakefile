require 'rake/testtask'
require 'rake/clean'

require 'fileutils'
require 'open3'
require 'yaml' # used for config files
require 'json' # used to parse Clang DB


require './common'
# ^ this file declares GEM_ROOT constant, other constants, and a some functions

# invoke a particular rake task by name (and then allow it to be run again later)
def run_task(task)
	Rake::Task[task].reenable
	Rake::Task[task].invoke
	# Rake::Task[task].reenable
	# src: http://stackoverflow.com/questions/577944/how-to-run-rake-tasks-from-within-rake-tasks
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






# generate depend file for gcc dependencies
# sh "gcc -MM *.c > depend"





# use 'rake clean' and 'rake clobber' to
# easily delete generated files

CLEAN.include('ext/rubyOF/constants/data_path.h')
CLEAN.include('ext/rubyOF/extconf_variables.rb')
CLEAN.include('ext/oF_apps/testApp/raw_oF_variables.yaml')
CLEAN.include('ext/oF_apps/testApp/oF_build_variables.yaml')

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
	task :project_generator, [:oF_project_name] do |t, args|
		project = args[:oF_project_name]
		
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
namespace :c_extension do
	# make the :test task depend on the shared
	# object, so it will be built automatically
	# before running the tests
	
	# rule to build the extension: this says
	# that the extension should be rebuilt
	# after any change to the files in ext
	
	c_library = "lib/#{NAME}/#{NAME}.so"
	# NOTE: This only works for linux, because it explicitly uses the ".so" extension
	
	
	
	# Why does the system detect changes to the oF sketch executable, but not the library?
	# 
		# So it looks like the build system links against the raw .o files generated by the open frameworks build system.
		# nothing in extconf.rb references the libOFSketch.a *at all*
		# that file has not been touched in forever, it's not being linked into anything,
		# it's basically no use to anyone.

		# I think what happened is I thought I needed this .a as an intermediate step, but it confused me.
		# So I ended up dropping the whole thing, and just using Ruby's facilities to figure it out?
		# rather than having to write makefiles
		# the following is quoted from a comment in 'Makefile.static_lib'
		# ----
			# this doesn't seem to work. might have to do this in a rakefile, because that's something I actually understand, lol.
			# these variables are coming up empty, and I'm not sure why.
		# ----
	# HOWEVER: The vestigial libOFSketch.a generation code can not be discarded.
		# While the library is vestigial, that part of the build process
		# generates 'oF_build_variables.yaml', which is used by extconf.rb to
		# configure various flags that should be passed to the complier / linker.
	# TODO: Re-examine the history of creating the build system, and attempt to refactor such that this (largely) vestigital pathway can actually be removed safely.
	
	
	
	# TODO: update source file list
	c_library_deps = Array.new
	# c_library_deps += Dir.glob("ext/#{NAME}/*{.rb,.c}")
	
	
	# Make sure the Ruby C extension is dependent on the oF sketch.
	# This way, when the sketch is altered, changes will propogate to the Ruby-level.
	c_library_deps << 'oF_project:build'
	
	# Ruby / Rice CPP files
	c_library_deps += Dir.glob("ext/#{NAME}/cpp/lib/**/*{.cpp,.h}")
	
	# 
	c_library_deps << "ext/#{NAME}/extconf.rb"
	c_library_deps << __FILE__ # depends on this Rakefile
	c_library_deps << RUBYOF_DATA_PATH_FILE # defines oF asset directory
	
	# c_library_deps << OF_BUILD_VARIABLE_FILE
	# TODO: ^ re-enable this ASAP
	
	# NOTE: adding OF_BUILD_VARIABLE_FILE to the dependencies for the 'c_library' makes it so extconf.rb has to run every time, because the variable file is being regenerated every time.
	
	
	# FIXME: can't seem to just run rake again to rebuild. keep having to clobber, and then do a full clean build again.
	
	
	# patch c constant file with proper data path
	file RUBYOF_DATA_PATH_FILE do
		FileUtils.mkdir_p File.dirname RUBYOF_DATA_PATH_FILE
		
		File.open(RUBYOF_DATA_PATH_FILE, 'w') do |f|
			f.puts "#define DATA_PATH \"#{RUBYOF_DATA_PATH}\""
		end
	end
	
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
		
		puts "=== Moving dynamic library into correct location..."
		
		FileUtils.cp "ext/#{NAME}/#{NAME}.so", "lib/#{NAME}"
		
		
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
	desc "Build the C extension"
	task :build => c_library
	
	
	
	
	
	# Not sure how often you want to regenerate this file, but not every time you build.
	# You need to run make and have something happen. If nothing gets build from the makefile, the clang database will end up empty.
	
	
	
	# TODO: make sure the clang symbols are generated as part of the standard build process
	# TODO: add clang symbols file to the .gitignore. Should be able to generate this, instead of saving it.
	
	
end




# === Manage ruby-level code
namespace :ruby do
	desc "testing"
	task :run do
		project = "example" # [boilerplate, example]
		Dir.chdir File.expand_path("bin/projects/#{project}/", GEM_ROOT) do
			puts "ruby level execution"
			
			exe_path = "./lib/main.rb"
			Kernel.exec "ruby #{exe_path}"
		end
	end
	
	desc "testing"
	task :debug do
		project = "example" # [boilerplate, example]
		Dir.chdir File.expand_path("bin/projects/#{project}/", GEM_ROOT) do
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
end





# add dependencies to default 'clean' / 'clobber' tasks
# NOTE: Don't edit the actual body of the task
task :clean   => ['oF_project:clean']
task :clobber => ['oF_deps:clobber', 'oF:clean']



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


desc "Build just the pure C++ parts"
task :build_cpp => ['oF:build', 'oF_project:build']


# Build dependencies shifted from explict to implied,
# so that you don't duplicate the work being done in :setup.
# This way, the build process will go a little faster.
desc "Build the whole project (Ruby and C++ combined)"
task :build => [
	'oF:build',
	'oF_project:build',                  # implicitly requires oF:build
	'oF_project:export_build_variables', # implicitly requires oF_project:build
	'oF_project:static_lib:build',
	
	'c_extension:build',
	# ^ multiple steps:
	#   +  extconf.rb -> makefile
	#   +  run the makefile -> build ruby dynamic lib (.so)
	#   +  move ruby dynamic lib (.so) into proper position
	#   +  ALSO rebuilds the clang symbol DB as necessary.
] do
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
	
	puts ">>> BUILD COMPLETE <<<"
end


# task :run => 'oF_project:run'
task :run => 'ruby:run'

task :build_and_run => [:build, :run] do
	
end


# NOTE: Assumes build options are set to make 'Debug'
desc "testing"
task :debug_project => [
	'oF:build',
	'oF_project:build',                  # implicitly requires oF:build
	'oF_project:debug'
] do
	
end

desc "testing"
task :debug => 'ruby:debug'





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

