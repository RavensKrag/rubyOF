# common configuration variables and methods
# that end up being used in both Oni/ext/oni/extconf.rb and Oni/Rakefile
# can be placed in this file.



NAME = 'rubyOF'


# this constant controlls whether or not the oF project
# will be built with debugging symbols or not.
# (you need this for GDB support, etc.)
OF_DEBUG = true
	# #debug off
	# -march=native -mtune=native -DNDEBUG

	# #debug on
	# g++ -c -g3 -DDEBUG


# === Platform-dependent build configuration variables

PLATFORM           = "linux64"
TARGET             = OF_DEBUG ? "Debug" : "Release"
NUMBER_OF_CORES    = 4

	# TODO: accept platform, target, and number of cores as Rake arguments
	# (maybe you actually want to figure out platform automatially)



# === these fils should be under the root directory of this Ruby gem
path_to_file = File.absolute_path(File.dirname(__FILE__))

COMMON_CONFIG = File.absolute_path(__FILE__)

GEM_ROOT = File.expand_path('./', path_to_file)
DYNAMIC_LIB_PATH = File.join(GEM_ROOT, 'bin', 'lib')








# === Clang database configuration
# (used for SublimeText autocomplete)
CLANG_SYMBOL_FILE = File.join GEM_ROOT, "compile_commands.json"






# === this path is most likely not going to be under the root directory of the Ruby gem
OF_ROOT = File.join(GEM_ROOT, "ext", "openFrameworks")





# === the sketch MAY be under the root directory, but could be configured to lie elsewhere

# 'ext/oni/cpp/oF_Test'
# 	'./mySketch'
# 	'./mySketch/lib'

OF_APP_DIR    = File.join(GEM_ROOT, "ext", "oF_apps")

# This way, you can set OF_SKETCH_ROOT to some other value before requiring this file,
# and everything else will update to match.
OF_SKETCH_NAME = "testApp"

unless defined? OF_SKETCH_ROOT
OF_SKETCH_ROOT = File.join(OF_APP_DIR, OF_SKETCH_NAME)
end

OF_SKETCH_SRC_DIR     = File.expand_path('src', OF_SKETCH_ROOT)
OF_SKETCH_SRC_FILES   = Dir.glob(File.join(OF_SKETCH_SRC_DIR, '*{.cpp,.h}'))

OF_SKETCH_BUILT_DIR   = File.expand_path(
                             "obj/#{PLATFORM}/#{TARGET}/src",
                             OF_SKETCH_ROOT
                        )
OF_SKETCH_BUILT_FILES = Dir[File.join(OF_SKETCH_BUILT_DIR, './*')]


OF_SKETCH_LIB_OUTPUT_PATH = File.expand_path('lib', OF_SKETCH_ROOT)
OF_SKETCH_LIB_FILE = File.join(OF_SKETCH_LIB_OUTPUT_PATH, 'libOFSketch.a')


OF_RAW_BUILD_VARIABLE_FILE = File.expand_path(
	                               "./raw_oF_variables.yaml",
	                               OF_SKETCH_ROOT
	                          )
OF_BUILD_VARIABLE_FILE     = File.expand_path(
	                               "./oF_build_variables.yaml",
	                               OF_SKETCH_ROOT
	                          )







require 'open3'

# interactive command-line program execution
def run_i(cmd_string, &block)
	exit_status = nil
	Open3.popen2e(cmd_string) do |stdin, stdout_and_stderr, wait_thr|
		begin
			output = stdout_and_stderr.gets
			
			# ----------
			
			# Perform project-specific find-and-replace operations
			# on the output stream.
			unless output.nil?
				output.gsub! GEM_ROOT, "[GEM_ROOT]"
			end
			
			# ----------
			
			puts output
		end until output.nil?
		
		
		exit_status = wait_thr.value
	end
	
	# raise exception if shell command ends in an error
	raise StandardError if exit_status != 0
	
	return exit_status
end






# Interactive command-line execution
# that tricks the subprocess into thinking it is running in a termal
# (pty is short for Psedo-Terminal)
# This means you can get pretty print / colored printing
# even in applications that sense connection to tty
def run_pty(*command)
	exit_status =
		SafePty.spawn(*command) do |stdout, stdin, pid|
			until stdout.eof? do
				puts stdout.readline
			end
		end

	if exit_status == 0
		puts "Done!"
	else
		raise "ERROR: Process in PTY failed with exit code #{status}!"
	end
end


# SafePty implementation fuses 4 different approaches.
# See 'docs/shell commands in ruby.odt' for details.

require 'pty'

module SafePty
	def self.spawn *command # &block
		begin
			PTY.spawn(*command) do |stdout, stdin, pid|
				begin
					yield stdout, stdin, pid
				ensure
					# This might cause problems if the block uses
					# something like #gets which won't recieve all
					# of the data in one pass...
					Process.wait pid
				end
			end
		rescue Errno::EIO
			# nothing			
			puts "Errno:EIO error detected for the following command:"
			p    command
			puts "  (most likely normal)"
			puts "  Most likely, child process has finished giving output"
			puts "  and closed it's output pipe."
		rescue PTY::ChildExited => e
			puts "The child process exited!"
			puts "(most likely normal)"
			puts "[child status] => #{e.status}"
		end
		
		status = $?.exitstatus
		return status
	end
end




