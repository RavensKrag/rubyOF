
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
		unless Dir.exists? path
			raise "ERROR: RubyOF Project '#{name}' not found. Check your spelling, or use full paths for projects not under the main project directory."
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
		# NOTE: It is possible that this method of figuring out if a path is relative or absolute may depend on "unix like pathnames" and as such, might not work on Windows.
		
		# src: https://stackoverflow.com/questions/1906823/given-a-path-how-to-determine-if-its-absolute-relative-in-ruby
		
		
		# TODO: accept actual relative paths, not just project names
		# they should be detected correctly, but they're not currently handled correctly. (still need to extract basename)
		
		
		
		pathname = Pathname.new(path_or_name)
		if pathname.relative?
			# relative path: assume relative to project directory
			
			# name of the project
			# (should be the same as the directory name)
			project_name = pathname               # retain some namespacing
			# project_name = pathname.basename.to_s # or not
			

			# root of the project
			project_path   = 
				(Pathname.new(GEM_ROOT) + 'bin' + 'projects' + pathname).to_s
			
			# TODO: Just use the Pathname type everywhere; would really be better
			
			
			return project_name, project_path
		else
			# absolute path: assume this is the exact location that should be used
			
			
			# absolute path is given. so set that part first
			project_path = path_or_name
			
			# the last token in the path is the name of the directory
			# aka, the name of the project
			project_name = pathname.basename.to_s
			
			
			
			return project_name, project_path
		end
	end
	
end


end
end
