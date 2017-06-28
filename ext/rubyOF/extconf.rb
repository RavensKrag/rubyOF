require 'mkmf-rice'
require 'fileutils'
require 'open3'

require 'yaml'

path_to_file = File.absolute_path(File.dirname(__FILE__))
gem_root = File.expand_path('../../', path_to_file)

require File.expand_path('./common', gem_root)
# ^ this file declares GEM_ROOT constant, other constants, and a some functions












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
		%w[
			fmodex
			glfw
			kiss
			poco
			tess2
			utf8cpp
		].any?{ |keyword|
			flag.include? keyword
		}
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
of_project_libs = of_build_variables['TARGET_LIBS'].join(' ')


# basic linker flags
ld_flags = ->(){
	ld_flags = 
		of_build_variables['ALL_LDFLAGS']
		.reject{ |flag|
			flag.include? "fmodex" # already specified in extconf.rb
		}
		.reject{ |flag|
			flag.include? '-rpath'
		}
	ld_flags.unshift "-Wl,-rpath=./libs:./bin/libs:#{DYNAMIC_LIB_PATH}" # add to front
	ld_flags = ld_flags.join(' ')
	
	
	# NOTE: may need to modify -rpath in the future
	# NOTE: specify directories for dynamic libraries relative to the root directory of this project, and then expand them into full paths before adding to -rpath. This means the gem will be able to find the dynamic libraries regaurdless of where the Ruby code is being called from.
	
	return ld_flags
}[]

# more linker flags
of_core_libs_dynamic_flags = 
	of_build_variables['OF_CORE_LIBS']
	.reject{ |flag|
		# remove the core dependencies, because extconf.rb specifies special versions.
		flag.include? File.join(OF_ROOT, 'libs')
	}
	.join(' ')




more_linker_flags = 
	[
		of_project_objs,
		of_project_addon_objs,
		of_project_libs,
		ld_flags,
		of_core_libs_dynamic_flags, # these flags are very important
	]
	.collect{  |string_blob|  string_blob.split.join(' ') }
	.join('   ')

$LDFLAGS += " " + more_linker_flags







# === Copy over dynamic libraries to the correct location

# -rpath flag specifies where to look for dynamic libraries
# (the system also has some paths that it checks for, but these are the "local dlls", basically)

# NOTE: DYNAMIC_LIB_PATH has been passed to -rpath

src = File.expand_path("./libs/fmodex/lib/linux64/libfmodex.so", OF_ROOT)
dest = DYNAMIC_LIB_PATH
FileUtils.copy(src, dest)

# TODO: make sure that the 'bin/libs' directory exists before copying. (Maybe fileutils will handle automatically? maybe not)












# === write variables used by extconf to file, for debug purposes
# (the file extension is just to give a hint to syntax highlighters)
File.open("./extconf_variables.rb", "w") do |f|
	# p global_variables
	f.puts global_variables.inspect
	
	# => [:$;, :$-F, :$@, :$!, :$SAFE, :$~, :$&, :$`, :$', :$+, :$=, :$KCODE, :$-K, :$,, :$/, :$-0, :$\, :$_, :$stdin, :$stdout, :$stderr, :$>, :$<, :$., :$FILENAME, :$-i, :$*, :$?, :$$, :$:, :$-I, :$LOAD_PATH, :$", :$LOADED_FEATURES, :$VERBOSE, :$-v, :$-w, :$-W, :$DEBUG, :$-d, :$0, :$PROGRAM_NAME, :$CXX, :$LIBS, :$LIBRUBYARG, :$LIBRUBYARG_STATIC, :$RICE_CPPFLAGS, :$RICE_LDFLAGS, :$RICE_PREFIX, :$RICE_USING_MINGW32, :$DEFLIBPATH, :$CPPFLAGS, :$LDFLAGS, :$CXXFLAGS, :$LDSHARED_CXX, :$OBJEXT, :$DLDFLAGS, :$LIBPATH, :$static, :$config_h, :$default_static, :$configure_args, :$libdir, :$rubylibdir, :$archdir, :$-p, :$-l, :$-a, :$sitedir, :$sitelibdir, :$sitearchdir, :$vendordir, :$vendorlibdir, :$vendorarchdir, :$mswin, :$bccwin, :$mingw, :$cygwin, :$netbsd, :$os2, :$beos, :$haiku, :$solaris, :$universal, :$dest_prefix_pattern, :$extout, :$extout_prefix, :$extmk, :$hdrdir, :$topdir, :$top_srcdir, :$arch_hdrdir, :$have_devel, :$INCFLAGS, :$CFLAGS, :$ARCH_FLAG, :$LOCAL_LIBS, :$libs, :$srcdir, :$EXEEXT, :$NONINSTALLFILES, :$defs, :$typeof, :$arg_config, :$extconf_h, :$PKGCONFIG, :$VPATH, :$LIBRUBYARG_SHARED, :$warnflags, :$ruby, :$preload, :$nmake, :$cleanfiles, :$distcleanfiles, :$target, :$LIBEXT, :$objs, :$srcs, :$INSTALLFILES, :$distcleandirs, :$installed_list, :$ignore_error, :$makefile_created, :$enable_shared, :$make, :$curdir, :$fileutils_rb_have_lchmod, :$fileutils_rb_have_lchown, :$1, :$2, :$3, :$4, :$5, :$6, :$7, :$8, :$9]
	
	compiler_variables = 
	[
		['$CXX', $CXX],
		['$LIBS', $LIBS],
		['$LIBRUBYARG', $LIBRUBYARG],
		['$LIBRUBYARG_STATIC', $LIBRUBYARG_STATIC],
		['$RICE_CPPFLAGS', $RICE_CPPFLAGS],
		['$RICE_LDFLAGS', $RICE_LDFLAGS],
		['$RICE_PREFIX', $RICE_PREFIX],
		['$RICE_USING_MINGW32', $RICE_USING_MINGW32],
		['$DEFLIBPATH', $DEFLIBPATH],
		['$CPPFLAGS', $CPPFLAGS],
		['$LDFLAGS', $LDFLAGS],
		['$CXXFLAGS', $CXXFLAGS],
		['$LDSHARED_CXX', $LDSHARED_CXX],
		['$OBJEXT', $OBJEXT],
		['$DLDFLAGS', $DLDFLAGS],
		['$LIBPATH', $LIBPATH],
		['$static', $static],
		['$config_h', $config_h],
		['$default_static', $default_static],
		['$configure_args', $configure_args],
		['$libdir', $libdir],
		['$rubylibdir', $rubylibdir],
		['$archdir', $archdir],
		['$defs', $defs],
	].to_h

	compiler_variables.each do |name, var|
		f.puts name
		f.puts "   #{var.inspect}"
	end
end





create_makefile('rubyOF/rubyOF')
