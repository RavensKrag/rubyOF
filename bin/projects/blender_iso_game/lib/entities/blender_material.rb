class BlenderMaterial < RubyOF::Material
	attr_reader :name
	
	def initialize(name)
		super()
		@name = name
	end
	
	# TODO: implement serialization methods
end
