require 'mkmf-rice'
require 'fileutils'
require 'open3'

require 'yaml'

path_to_file = File.absolute_path(File.dirname(__FILE__))
gem_root = File.expand_path('../../', path_to_file)

require File.expand_path('./common', gem_root)
# ^ this file declares GEM_ROOT constant, other constants, and a some functions









require 'fileutils'
require 'open3'

require 'yaml'


have_library("stdc++")






# === Set extra flags based on data from oF build system

of_build_variables = YAML.load_file(OF_BUILD_VARIABLE_FILE)

# TODO: centralize setting of build variables. Some duplication between extconf.rb and rakefile.






$CPPFLAGS
# => "-I/home/ravenskrag/Experiments/RubyCPP/Oni/ext/oni/cpp/oF_Test/mySketch/src -I/home/ravenskrag/Experiments/OpenFrameworks/of_v0.9.3_linux64_release//libs/openFrameworks/  $(DEFS) $(cppflags)  -I/home/ravenskrag/.rvm/gems/ruby-2.1.1/gems/rice-2.1.0/ruby/lib/include"
$LDFLAGS
# => "-L. -fstack-protector -rdynamic -Wl,-export-dynamic  -L/home/ravenskrag/.rvm/gems/ruby-2.1.1/gems/rice-2.1.0/ruby/lib/lib -lrice"



# $(OPTIMIZATION_CFLAGS) $(CFLAGS) $(CXXFLAGS) $(OF_CORE_INCLUDES_CFLAGS)

	# "-O3 -DNDEBUG -march=native -mtune=native -Wall -std=c++14 -DGCC_HAS_REGEX -DOF_USING_GTK -DOF_USING_GTK -DOF_USING_MPG123 -fPIC  -D_REENTRANT -pthread"

$LIBS
   # => "-lpthread -ldl -lcrypt -lm   -lc"
$LIBRUBYARG
   # => "-Wl,-R -Wl,/home/ravenskrag/.rvm/rubies/ruby-2.1.1/lib -L/home/ravenskrag/.rvm/rubies/ruby-2.1.1/lib -lruby"
$LIBRUBYARG_STATIC
   # => "-Wl,-R -Wl,/home/ravenskrag/.rvm/rubies/ruby-2.1.1/lib -L/home/ravenskrag/.rvm/rubies/ruby-2.1.1/lib -lruby-static"
$CXXFLAGS
   # => " -Wall -g"
$LDSHARED_CXX
   # => "g++ -shared"





# NOTE: there is also OPTIMIZATION_CFLAGS and OPTIMIZATION_LDFLAGS, but those are not used here
optimization_flags = of_build_variables['PLATFORM_OPTIMIZATION_CFLAGS_RELEASE'].join(' ')
cxx_flags          = of_build_variables['CFLAGS']
                     	.reject{ |flag|
                     		["-fPIC", "-Wall"].include? flag
                     	}
                     	.join(' ')

$CXXFLAGS += " " + [
                   	optimization_flags,
                   	cxx_flags,
                   ].join(' ')





c_flags = 
	of_build_variables['PROJECT_INCLUDE_CFLAGS'] # includes files for core, addons, everything
	.reject{ |flag|
		# reject these libraries, because they have already been specified in extconf.rb above
		# %w[
		# 	fmodex
		# 	glfw
		# 	kiss
		# 	poco
		# 	tess2
		# 	utf8cpp
		# ].any?{ |keyword|
		# 	flag.include? keyword
		# }
	}
	.reject{ |flag|
		# bunch of local paths in here, not sure if they are relevant at the Ruby level?
		# gonna get rid of them for now
		%w[-I./ -I/. -I.].any?{ |fragment|
			flag.include? fragment
		}
	}
	.join(' ')
# p c_flags


$CPPFLAGS += " " + c_flags


# Set this so build system outputs formatted error messages,
# even when running through the Rakefile
# (open3 strips formatting, as gcc senses it's not connected to a terminal)
$CFLAGS += " -fdiagnostics-color=always"








# this variable is only set when addons are specified.
# need to be able to handle the case where no addons are being used.
of_build_variables['OF_PROJECT_ADDONS_OBJS'] ||= Array.new



of_build_variables['OF_PROJECT_OBJS']

of_build_variables['OBJS_WITHOUT_EXTERNAL']
of_build_variables['OBJS_WITH_PREFIX']

# these last two are the same thing.
# they seem to intend to give full paths for the files specified in OF_PROJECT_OBJS
# but there is some sort of bug.
# 
# ex) 
# 	obj/linux64/Release/src/main.o
# 	obj/linux64/Release//home/ravenskrag/Experiments/RubyCPP/Oni/ext/oni/cpp/oF_Test/mySketch/src/main.o
# 
# notice how the second line puts the root of the path at an odd position...
# (luckly I already had code to expand these local paths)




of_project_objs = 
	of_build_variables['OF_PROJECT_OBJS']
	.collect{ |line|
		File.expand_path("./#{line}", OF_SKETCH_ROOT)
	}.join(' ')


of_project_addon_objs = of_build_variables['OF_PROJECT_ADDONS_OBJS'].join(' ')


# libopenFrameworks.a
# of_project_libs = of_build_variables['TARGET_LIBS'].join(' ')
of_project_libs = "-L#{DYNAMIC_LIB_PATH} -lopenFrameworks#{OF_DEBUG ? "Debug" : ""}"
	# link against "libopenFrameworksDebug.so" or "libopenFrameworks.so"
	# and assume that the dynamic libraries have already been copied
	# to the final location specified by DYNAMIC_LIB_PATH

# basic linker flags
ld_flags = ->(){
	ld_flags = 
		of_build_variables['ALL_LDFLAGS']
		.reject{ |flag|
			flag.include? '-rpath'
		}
	ld_flags.unshift "-Wl,-rpath=.:.bin/lib:#{DYNAMIC_LIB_PATH}" # add to front
	ld_flags = ld_flags.join(' ')
	
	
	# NOTE: may need to modify -rpath in the future
	# NOTE: specify directories for dynamic libraries relative to the root directory of this project, and then expand them into full paths before adding to -rpath. This means the gem will be able to find the dynamic libraries regaurdless of where the Ruby code is being called from.
	
	return ld_flags
}[]

# more linker flags
of_core_libs_dynamic_flags = 
	of_build_variables['OF_CORE_LIBS']
	.join(' ')



list_of_linker_flags = [
	# of_project_objs,
	# of_project_addon_objs,
	# ^ these two will now be part of a static library (.a file)
	# OF_SKETCH_LIB_FILE, # <-- here is that library
	
	of_project_libs,
	ld_flags,
	of_core_libs_dynamic_flags, # these flags are very important
]


more_linker_flags = 
	list_of_linker_flags
	.collect{  |string_blob|  string_blob.split.join(' ') }
	.join('   ')

$LDFLAGS += " " + more_linker_flags

# # DEBUG PRINT
# p list_of_linker_flags
# p $LDFLAGS







# manually set the entire $warnflags variable
# removing the options that don't make sense for C++
# (you get warnings on compile that the options are unrecognized)
$warnflags = 
   "-Wall -Wextra -Wno-unused-parameter -Wno-parentheses -Wno-long-long -Wno-missing-field-initializers -Wunused-variable -Wpointer-arith -Wwrite-strings -Wdeprecated-declarations -Wno-packed-bitfield-compat -Wsuggest-attribute=noreturn -Wsuggest-attribute=format -Wno-maybe-uninitialized"













create_makefile('rubyOF/rubyOF')



require File.join(GEM_ROOT, 'ext', NAME, 'extconf_printer.rb')

filepath = File.join(path_to_file, 'extconf_variables.yaml')
write_extconf_variables_to_file(filepath)
