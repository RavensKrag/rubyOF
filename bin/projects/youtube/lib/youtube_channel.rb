class YoutubeChannel
	attr_reader :icon, :name
	attr_accessor :icon_pos, :text_pos, :text_color
	
	attr_reader :text_mesh
	
	def initialize(icon, name, font)
		@icon = icon # RubyOF::Image
		@name = name # String
		
		@icon_pos = CP::Vec2.new(0,0)
		@text_pos = CP::Vec2.new(0,0)
		
		x,y = [0,0]
		vflip = true
		@text_mesh    = font.get_string_mesh(@name, x,y, vflip)
		
		@text_color = nil
	end
end
