# TODO: move this into RubyOF core
require 'singleton'

module RubyOF
	
class ResourceManager
	include Singleton
	# access using ResourceManager.instance
	# src: https://ieftimov.com/singleton-pattern
	
	def initialize
		@storage = Hash.new
	end
	
	# load resource. return cached copy if already loaded
	def load(data_obj)
		puts "ResourceManager#load"
		case data_obj
		when RubyOF::TrueTypeFontSettings
			# puts "-----> loading font"
			# use TrueTypeFontSettings to load TrueTypeFont
			@storage[:fonts] ||= Hash.new
			
			
			unless @storage[:fonts].has_key? data_obj
				font = RubyOF::TrueTypeFont.new
				font.load(data_obj)
				@storage[:fonts][data_obj] = font
			end
			
			return @storage[:fonts][data_obj]
		end
	end
	
	# remove resource from the cache
	def unload()
		
	end
end


end
