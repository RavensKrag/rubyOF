

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




