# encoding: UTF-8

require 'pathname'

project_root = Pathname.new(__FILE__).expand_path.dirname.parent
puts "project_root = #{project_root}"

require (project_root/'config'/'build_variables')
# ^ defines the GEM_ROOT constant

require (GEM_ROOT/'bin'/'main')
# ^ defines main() function



MAIN_OBJ = self



# TODO: split stderr and stdout into two separate streams / files
# (did this before in livecode2)


# run the main program
main(project_root)


