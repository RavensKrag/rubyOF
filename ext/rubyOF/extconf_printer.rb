# === write variables used by extconf to file, for debug purposes
def write_extconf_variables_to_file(filepath)
	File.open(filepath, "w") do |f|
		# f.puts global_variables.inspect
		# => [:$;, :$-F, :$@, :$!, :$SAFE, :$~, :$&, :$`, :$', :$+, :$=, :$KCODE, :$-K, :$,, :$/, :$-0, :$\, :$_, :$stdin, :$stdout, :$stderr, :$>, :$<, :$., :$FILENAME, :$-i, :$*, :$?, :$$, :$:, :$-I, :$LOAD_PATH, :$", :$LOADED_FEATURES, :$VERBOSE, :$-v, :$-w, :$-W, :$DEBUG, :$-d, :$0, :$PROGRAM_NAME, :$CXX, :$LIBS, :$LIBRUBYARG, :$LIBRUBYARG_STATIC, :$RICE_CPPFLAGS, :$RICE_LDFLAGS, :$RICE_PREFIX, :$RICE_USING_MINGW32, :$DEFLIBPATH, :$CPPFLAGS, :$LDFLAGS, :$CXXFLAGS, :$LDSHARED_CXX, :$OBJEXT, :$DLDFLAGS, :$LIBPATH, :$static, :$config_h, :$default_static, :$configure_args, :$libdir, :$rubylibdir, :$archdir, :$-p, :$-l, :$-a, :$sitedir, :$sitelibdir, :$sitearchdir, :$vendordir, :$vendorlibdir, :$vendorarchdir, :$mswin, :$bccwin, :$mingw, :$cygwin, :$netbsd, :$os2, :$beos, :$haiku, :$solaris, :$universal, :$dest_prefix_pattern, :$extout, :$extout_prefix, :$extmk, :$hdrdir, :$topdir, :$top_srcdir, :$arch_hdrdir, :$have_devel, :$INCFLAGS, :$CFLAGS, :$ARCH_FLAG, :$LOCAL_LIBS, :$libs, :$srcdir, :$EXEEXT, :$NONINSTALLFILES, :$defs, :$typeof, :$arg_config, :$extconf_h, :$PKGCONFIG, :$VPATH, :$LIBRUBYARG_SHARED, :$warnflags, :$ruby, :$preload, :$nmake, :$cleanfiles, :$distcleanfiles, :$target, :$LIBEXT, :$objs, :$srcs, :$INSTALLFILES, :$distcleandirs, :$installed_list, :$ignore_error, :$makefile_created, :$enable_shared, :$make, :$curdir, :$fileutils_rb_have_lchmod, :$fileutils_rb_have_lchown, :$1, :$2, :$3, :$4, :$5, :$6, :$7, :$8, :$9]
		
		
		ignore_list = [:$;, :$-F, :$@, :$!, :$SAFE, :$~, :$&, :$`, :$', :$+, :$=, :$KCODE, :$-K, :$,, :$/, :$-0, :$\, :$_, :$stdin, :$stdout, :$stderr, :$>, :$<, :$., :$FILENAME, :$-i, :$*, :$?, :$$, :$:, :$-I, :$LOAD_PATH, :$", :$LOADED_FEATURES, :$VERBOSE, :$-v, :$-w, :$-W, :$DEBUG, :$-d, :$0, :$PROGRAM_NAME, :$0, :$1, :$2, :$3, :$4, :$5, :$6, :$7, :$8, :$9]
		
		compiler_variables = 
			(global_variables - ignore_list).collect{ |global_variable_sym|
				data = eval global_variable_sym.to_s
				# WARNING: Using eval to resolve global variables
				# (there is no analogous method to instance_variable_get())
				
				[global_variable_sym.to_s, data]
			}.to_h
		
		
		
		
		# The first chunk of data is just a list of all possible variables.
		# The second chunk is the 'actual' output.
		data_out = [
			global_variables.inspect,
			compiler_variables
		]
		
		f.puts data_out.to_yaml

	end
end

