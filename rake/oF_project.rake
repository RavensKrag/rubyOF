

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

