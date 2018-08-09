require 'pathname'

# NOTE: Don't indent this block. This formatting makes it easier for 'project_generator.rb' to edit.

Dir.chdir Pathname.new(__FILE__).dirname.expand_path do
	
GEM_ROOT = Pathname.new('../../../..').expand_path
puts "GEM_ROOT = #{GEM_ROOT}"

end
