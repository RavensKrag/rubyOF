
# TODO: move this into the oF_deps namespace, and then consolodate all path definitions.
# NOTE: Assumes you're running on Linux
desc "Examine compiled libraries (linux)"
task :examine, [:library_name] do |t, args|
	name = args[:library_name].to_sym
	path =
		case name
			when :kiss
				"ext/oF_deps/master/custom/kiss/custom_build/lib/libkiss.a"
			when :tess2
				"ext/oF_deps/master/custom/tess2/lib/#{PLATFORM}/libtess2.a"
			when :oF_core
				"ext/openFrameworks/libs/openFrameworksCompiled/lib/linux64/libopenFrameworks.a"
			when :oF_project
				if OF_DEBUG
					"ext/oF_apps/#{OF_SKETCH_NAME}/bin/#{OF_SKETCH_NAME}_debug"
				else
					"ext/oF_apps/#{OF_SKETCH_NAME}/bin/#{OF_SKETCH_NAME}"
				end
			when :oF_project_lib
				"ext/oF_apps/#{OF_SKETCH_NAME}/lib/libOFSketch.a"
			when :rubyOF
				"ext/rubyOF/rubyOF.so"
		end
	
	case File.extname path
		when ".a"
			run_i "nm -C #{path}"
		when ".so"
			run_i "nm -C -D #{path}"
		else # linux executable
			run_i "nm -C #{path}"
	end
	
	# # the -C flag is for de-mangling the C++ function names
	# run_i "nm -C #{path_to_lib}"
	
	# # this command will let you see inside an .so
	# # nm -C -D libfmodex.so
	# # src: http://stackoverflow.com/questions/4514745/how-do-i-view-the-list-of-functions-a-linux-shared-library-is-exporting
end

