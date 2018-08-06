module CP
	module Shape
		
		
class Rect < Poly
	def to_yaml_type
		"!ruby/object:#{self.class}"
	end

	def encode_with(coder)
		coder.represent_map to_yaml_type, {
			'body' => self.body,
			'width' => @width,
			'height' => @height,
			'verts' => self.verts,
		}
	end

	def init_with(coder)
		body = coder.map['body']
		width = coder.map['width']
		height = coder.map['height']
		
		initialize(body, width, height)
		
		verts = coder.map['verts']
		self.set_verts!(verts, offset=CP::Vec2.new(0,0))
	end
end



end
end
