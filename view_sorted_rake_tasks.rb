#!/usr/bin/env ruby

p ARGV[0]
flags = 
	case ARGV[0]
		when "all"
			"--all"
		when nil
			"" # no additional flags to add
		else
	end

tasks = `env RUBYOF_PROJECT="youtube" rake --tasks #{flags}`
task_lines = task_lines = tasks.each_line.to_a

a,b = task_lines.partition{|x| x.include? ":"} # namespaced vs not namespaced
b,c = b.partition{|x| x.include? "/home"} # filepaths vs not filepaths


# a b and c came from a sorted collection,
# and thus will remain sorted
namespaced     = a
file_tasks     = b
non_namespaced = c


oF_tasks, not_oF_tasks    = namespaced.partition{|x| x.include? 'oF'}
deps, not_deps_namespaced = not_oF_tasks.partition{|x| x.include? 'deps' }

oF_deps, core_oF = oF_tasks.partition{|x| x.include? 'deps' }

# p oF_deps.sort




puts file_tasks + deps + oF_deps + core_oF + not_deps_namespaced + non_namespaced
