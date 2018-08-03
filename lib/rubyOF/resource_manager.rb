require 'singleton'
require 'weakref'

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
		# Store references using WeakRef, so that when the resource manager holds the last reference to a resource, the resource can be freed.
		# src: https://endofline.wordpress.com/2011/01/09/getting-to-know-the-ruby-standard-library-weakref/
		
		# puts "ResourceManager#load"
		case data_obj
		when RubyOF::TrueTypeFontSettings
			# puts "-----> loading font"
			# use TrueTypeFontSettings to load TrueTypeFont
			@storage[:fonts] ||= Hash.new
			
			
			stored = @storage[:fonts][data_obj]
			if( stored.nil? || # never loaded
				(stored.is_a?(WeakRef) && !stored.weakref_alive?) # got unloaded
			)
				font = RubyOF::TrueTypeFont.new
				font.load(data_obj)
				@storage[:fonts][data_obj] = WeakRef.new(font)
			end
			
			# return the underlying object, not the WeakRef wrapper
			return @storage[:fonts][data_obj].__getobj__
		end
	end
	
	# remove resource from the cache
	def unload()
		
	end
end


end
