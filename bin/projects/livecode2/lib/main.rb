# encoding: UTF-8

require 'pathname'

project_root = Pathname.new(__FILE__).expand_path.dirname.parent
puts "project_root = #{project_root}"

require (project_root/'config'/'build_variables')
# ^ defines the GEM_ROOT constant

require (GEM_ROOT/'bin'/'main')
# ^ defines main() function

main(project_root)
