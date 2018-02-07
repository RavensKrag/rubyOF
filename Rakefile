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
load './rake/oF_project.rake'
load './rake/extension.rake'


# defines RubyOF::Build.create_project and RubyOF::Build.load_project
require File.join(GEM_ROOT, 'build', 'build.rb')



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
