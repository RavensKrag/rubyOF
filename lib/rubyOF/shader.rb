module RubyOF

class Shader
	# private :load_oneNameVertAndFrag, :load_VertFragGeom
	
	alias :old_init :initialize
	def initialize
		old_init()
		
		@livecoding_timestamp = nil
	end
	
	private :load_shaders__cpp
	def load_glsl(*args)
		
		if(args.length <= 3)
			p args.map{|x| x.to_s }
			load_shaders__cpp(args.map{|x| x.to_s })
		else
			raise ArgumentError, 'Expected either one path (vertex and fragment shaders have the same name, i.e. dof.vert and dof.frag) or up to 3 paths: vert,frag,geom (geometry shader is optional)'
		end
		
		# case args.length
		# when 1
		# 	load_oneNameVertAndFrag(args.first)
		# when 2,3
		# 	load_VertFragGeom(*args)
		# else
		# 	raise ArgumentError, 'Expected either one path (vertex and fragment shaders have the same name, i.e. dof.vert and dof.frag) or up to 3 paths: vert,frag,geom (geometry shader is optional)'
		# end
		
	end
	
	
	# dynamic reloading of compositing shader
	# (code copied from RenderBatch#reload_shaders)
	def live_load_glsl(vert_shader_path, frag_shader_path, geom_shader_path=nil)
		paths =
			[
				vert_shader_path,
				frag_shader_path,
				geom_shader_path
			]
			.compact
			.collect{ |path| Pathname.new path  }
		
		# p @livecoding_timestamp
		
		if(@livecoding_timestamp.nil? || 
			paths.any?{|f| f.mtime > @livecoding_timestamp }
		)
			puts "reloading alpha compositing shaders..."
			
			self.load_glsl(*paths)
			
			# careful - these shaders don't go through the same pre-processing step as the ones in Material, so special directives like these:
			# 
			#    %glsl_version%
			#    %extensions%
			# 
			# won't get applied, but #define statements will.
			# 
			# (the % preprocessing is defined in ofGLProgrammableRenderer.cpp)
			# (search for ofStringReplace)
			# 
			# (#define preprocessing is defined in ofShader.cpp)
			# (search for regex_replace)
			
			@livecoding_timestamp = Time.now
		end
		
	end
end


end
