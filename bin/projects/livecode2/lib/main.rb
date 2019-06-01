# encoding: UTF-8

require 'pathname'

project_root = Pathname.new(__FILE__).expand_path.dirname.parent
puts "project_root = #{project_root}"

require (project_root/'config'/'build_variables')
# ^ defines the GEM_ROOT constant

require (GEM_ROOT/'bin'/'main')
# ^ defines main() function











# open alternate files
data_dir = project_root / 'bin' / 'data'
stdout_logfile = File.new(data_dir / 'output.log', 'a')
stderr_logfile = File.new(data_dir / 'output.log', 'a')

[stdout_logfile, stderr_logfile].each do |io|
	io.sync = true # flush to OS level so 'tail -f' works as expected
end



# dup the streams
stdout_term = $stdout.dup
stderr_term = $stderr.dup

[stdout_term, stdout_term].each do |io|
	io.sync = true # flush to OS level so 'tail -f' works as expected
end

$stdout.reopen stdout_logfile
$stderr.reopen stderr_logfile


# connect irb output back to terminal
STDOUT = stdout_term
STDERR = stderr_term




# output message to log file 
5.times do
	puts ''
end
puts "starting new session: #{Time.now}"
puts ''

# run the main program
main(project_root)





# close the files
[stdout_logfile, stderr_logfile].each do |io|
	io.close
end


# restore streams to default value (using duped copies)
$stdout.reopen stdout_term
$stderr.reopen stdout_term



# FIXME: clean this up a bit more
# need to dup the IO file descriptor thing so that I can restore it
# (IO#reopen is a weird method)
# but then need to save the duped thing to a constant, otherwise the repl thread can't seem to grab a hold of it
# then, need to remember to flush the REPL thread, otherwise it doesn't out to console.
	# do I need to run sync on the duped IO?
