

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
