class BlenderMaterial < RubyOF::OFX::InstancingMaterial
	attr_reader :name
	
	def initialize(name)
		super()
		@name = name
	end
	
	# TODO: implement serialization methods
end
