# use 'rake clean' and 'rake clobber' to
# easily delete generated files


CLEAN.include(OF_RAW_BUILD_VARIABLE_FILE)
CLEAN.include(OF_BUILD_VARIABLE_FILE)

# NOTE: Clean / clobber tasks may accidentally clobber oF dependencies if you are not careful.
CLEAN.include('ext/rubyOF/Makefile')
CLEAN.include('ext/**/*{.o,.log,.so}')
CLEAN.include('ext/**/*{.a}')
	# c1 = CLEAN.clone
	# p CLEAN
CLEAN.exclude('ext/openFrameworks/**/*')
CLEAN.exclude('ext/oF_deps/**/*')
# ^ remove the openFrameworks core
	# c2 = CLEAN.clone
	# p CLEAN
# CLEAN.exclude('ext/oF_apps/**/*')
# # ^ remove the test apps as well



# Clean up clang file index as well
# (build from inspection of 'make' as it builds the c-library)
CLEAN.include(CLANG_SYMBOL_FILE)





CLOBBER.include('bin/lib/*.so')
CLOBBER.include('lib/**/*.so')
CLOBBER.exclude('ext/openFrameworks/**/*')
CLOBBER.exclude('ext/oF_deps/**/*')





	# c3 = CLOBBER.clone
	# p CLOBBER
# CLOBBER.include('lib/**/*.gem') # fix this up. I do want to clobber the gem tho

	# require 'irb'
	# binding.irb

	# exit
	# raise "WHOOPS"

