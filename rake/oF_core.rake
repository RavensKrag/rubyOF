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
