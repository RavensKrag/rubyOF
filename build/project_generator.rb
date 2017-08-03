require 'fileutils'
require 'pathname'

gem_root = Pathname.new(__FILE__).expand_path.dirname.parent
puts "gem_root = #{gem_root.inspect}"

GEM_ROOT = gem_root.to_s
require (gem_root/'build'/'build.rb')
# require (gem_root/'common.rb')

# TODO: Improve the #update method to understand the versions of RubyOF, so that it will 'upgrade' from older project formats to newer ones.

module RubyOF
	module Build

class ProjectGenerator
	def initialize
		
	end
	
	# list only the methods I defined, and exclude the default stuff
	def help
		self.methods - Object.new.methods
	end
	
	# Generate RubyOF project by copying the 'boilerplate' project
	def create(rubyOF_project)
		# == Figure where to place the new project
		RubyOF::Build.create_project(rubyOF_project) do |path|
			# == Copy the template project into the target location
			template_project_name = 'boilerplate'
			
			# Need to clean the example first, so you don't copy built files
			# run_task('clean_project', template_project_name)
			# ^ NOTE: This has been separated from the Rakefile, so it is no longer possible to clean out the example. But that's not actually so bad.
			
			# Find full path to template
			# NOTE: template_name == template_project_name
			template_name, template_path =
				RubyOF::Build.load_project(template_project_name)
			
			# Copy the full directory to destination
			FileUtils.mkdir_p File.dirname(path) # make sure containg dir exists
			FileUtils.cp_r template_path, path
		end
		
		
		# # NOTE: This is the job for a unit test. Don't test this here
		# # The name inputted should be exactly the same as the name outputted.
		# # If not, there is a problem with the parsing function.
		# if template_project_name != template_name
		# 	raise "ERROR: RubyOF::Build.create_project() parsed incorrectly." +
		# 	      " Given '#{template_project_name}' "
		# end;
		
		
		
		# Make sure that the GEM_ROOT path is set correctly,
		# regaurdless of where the new project has been created.
		self.update(rubyOF_project)
	end
	
	# Take an existing RubyOF project, and update the GEM_ROOT path
	def update(rubyOF_project)
		name, path = RubyOF::Build.load_project rubyOF_project
		
		# TODO: remove this once everything is updated to use Pathname
		project_root = Pathname.new(path).expand_path
		gem_root     = Pathname.new(GEM_ROOT)
		
		puts "gem_root     = #{gem_root}"
		puts "project_root = #{project_root}"
		
		# === Update files where GEM_ROOT is declared.
		target_file = 'build_variables.rb'
		
		[
			(project_root/'config'/'build_variables.rb'),
			(project_root/'Gemfile')
		].each do |path|
			# Declare the new GEM_ROOT path
			# (use relative paths for projects inside the gem)
			path_to_root = 
				if path.to_s.start_with? gem_root.to_s
					# Relative path
					# (project is inside the default directory)
					gem_root.relative_path_from(path.dirname)
				else
					# Absolute path
					# (project is outside of the default directory)
					gem_root
				end
			
			puts path_to_root
			
			# Load the file
			unless path.exist?
				raise "ERROR: Could not find '#{path.basename}' @ path #{path}"
			end
			file_lines = File.readlines(path)
			# p file_lines
			
			# Find the line that sets GEM_ROOT
			# and replace it with the new declaration
			file_lines.collect! do |line|
				if line.start_with? 'GEM_ROOT = '
					"GEM_ROOT = Pathname.new('#{path_to_root}').expand_path\n"
				else
					line
				end
			end
			
			# Write the modified contents back into the file
			File.open(path, "w") do |f|
				f.write file_lines.join
			end
		end
		
	end
end


end
end



generator = RubyOF::Build::ProjectGenerator.new
puts "Use the variable 'generator' to manage projects"

require 'irb'
binding.irb

