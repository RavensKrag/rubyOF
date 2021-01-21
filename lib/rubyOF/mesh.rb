module RubyOF


class Mesh
	alias :setMode__cpp :setMode
	private :setMode__cpp
	
	OF_PRIMITIVES = [
		:triangles,
		:triangle_strip,
		:triangle_fan,
		:lines,
		:line_strip,
		:line_loop,
		:points,
	]
	
	def setMode(mode)
		i = OF_PRIMITIVES.index(mode)
		
		raise ArgumentError, "Given mesh mode #{mode.inspect} is not a valid mesh mode. Please use one of the following: #{OF_PRIMITIVES.inspect}" if i.nil?
		
		setMode__cpp(i)
	end
	
	
	
	private :draw__cpp
	
	OF_POLY_RENDER_MODE = [
		:points,
		:wireframe,
		:fill
	]
	
	def draw(render_mode=:fill)
		i = OF_POLY_RENDER_MODE.index(render_mode)
		
		raise ArgumentError, "Given poly render mode #{mode.inspect} is not a valid mesh mode. Please use one of the following: #{OF_POLY_RENDER_MODE.inspect}" if i.nil?
		
		draw__cpp(i)
	end
end

class VboMesh
	private :draw_instanced__cpp
	
	def draw_instanced(instance_count, render_mode=:fill)
		i = OF_POLY_RENDER_MODE.index(render_mode)
		
		raise ArgumentError, "Given poly render mode #{mode.inspect} is not a valid mesh mode. Please use one of the following: #{OF_POLY_RENDER_MODE.inspect}" if i.nil?
		
		draw_instanced__cpp(i, instance_count)
	end
end





end
