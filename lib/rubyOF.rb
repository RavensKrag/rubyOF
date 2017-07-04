puts "load C code..."

# Stolen from Gosu's code to load the dynamic library
if defined? RUBY_PLATFORM and
%w(-win32 win32- mswin mingw32).any? { |s| RUBY_PLATFORM.include? s } then
	ENV['PATH'] = "#{File.dirname(__FILE__)};#{ENV['PATH']}"
end

[
	'rubyOF/rubyOF',
	'rubyOF/version',
	'rubyOF/meta',
	'rubyOF/freezable'
].each do |path|
	require File.expand_path(path, File.absolute_path(File.dirname(__FILE__)))
end
puts "loading ruby code"

class Numeric
	def degrees
		# Assume that this is an angle in radians, and convert to degrees
		# This is so you can write 20.degrees instead of 20.to_deg
		self/ 180.0 * Math::PI
	end
end




module RubyOF


class Window
	alias :rice_cpp_initialize :initialize
	def initialize(title, width, height)
		# pass Ruby instance to C++ land for callbacks, etc
		rice_cpp_initialize(self, width, height)
		
		# ensure that all windows have a title by requring one in the constructor
		self.window_title = title
	end
	
	
	def setup
		puts "ruby: Window#setup"
	end
	
	def update
		puts "ruby: Window#update"
	end
	
	def draw
		puts "ruby: Window#draw"
	end
	
	# NOTE: this method can not be called 'exit' because there is a method Kernel.exit
	def on_exit
		puts "ruby: exiting application..."
	end
	
	
	def key_pressed(key)
		p [:pressed, key]
	end
	
	def key_released(key)
		p [:released, key]
	end
	
	
	def mouse_moved(x,y)
		@p = [x,y]
		p @p
	end
	
	def mouse_pressed(x,y, button)
		p [:pressed, x,y, button]
	end
	
	def mouse_released(x,y, button)
		p [:released, x,y, button]
	end
	
	def mouse_dragged(x,y, button)
		p [:dragged, x,y, button]
	end
	
	
	def mouse_entered(x,y)
		p [:mouse_in, x,y]
	end
	
	def mouse_exited(x,y)
		p [:mouse_out, x,y]
	end
	
	
	def mouse_scrolled(x,y, scrollX, scrollY)
		p [:mouse_scrolled, x,y, scrollX, scrollY]
	end
	
	
	def window_resized(w,h)
		p [:resize, w,h]
	end
	
	def drag_event(files, position)
		p [files, position]
	end
	
	def got_message()
		# NOTE: not currently bound
	end
	
	
	
	
	private
	
	def draw_debug_info(start_position, row_spacing, z=1)
		[
			"mouse: #{@p.inspect}",
			"window size: #{window_size.to_s}",
			"dt: #{ofGetLastFrameTime.round(5)}",
			"fps: #{ofGetFrameRate.round(5)}"
		].each_with_index do |string, i|
			x,y = start_position
			y += i*row_spacing
			
			ofDrawBitmapString(string, x,y,z)
		end
	end
end


module Graphics
	def style_stack(&block)
		begin
			ofPushStyle()
			yield
		ensure 
			ofPopStyle()
		end
	end
	
	def matrix_stack(&block)
		begin
			ofPushMatrix()
			yield
		ensure 
			ofPopMatrix()
		end
	end
end


class Color
	include Freezable
end

class Point
	include Freezable
	
	def to_s
		format = '%.03f'
		x = format % self.x
		y = format % self.y
		z = format % self.z
		
		return "(#{x}, #{y}, #{z})"
	end
	
	def inspect
		super()
	end
	
	
	
	# hide C++ level helper methods
	private :get_component
	private :set_component
	
	
	# get / set value of a component by numerical index
	def [](i)
		return get_component(i)
	end
	
	def []=(i, value)
		return set_component(i, value.to_f)
	end
	
	
	# get / set values of component by axis name
	%w[x y z].each_with_index do |component, i|
		# getters
		# (same as array-style interface)
		define_method component do
			get_component(i)
		end 
		
		# setters
		# (use special C++ function to make sure data is written back to C++ land)
		define_method "#{component}=" do |value|
			set_component(i, value.to_f)
		end 
	end
	
	
	# discards the Z component.
	def to_cpvec2
		return CP::Vec2.new(self.x, self.y)
	end
end

# This is basically the bounding box class
class Rectangle
	def to_s
		"<x: #{self.x}, y: #{self.y}, width: #{self.width}, height: #{self.height} | (#{self.left}, #{self.bottom}) -> (#{self.right}, #{self.top})>"
	end
	
	def inspect
		super()
	end
	
	# convert to a Chipmunk CP::BB object
	def to_cpbb
		return CP::BB.new(self.left, self.bottom, self.right, self.top)
	end
	
	# Ruby-level wrapper to replicate the overloaded C++ interface.
	def inside?(*args)
		signature_error = "Specify a point(two floats, or one Point), line(two Point), or rectangle(one Rectangle)."
		
		raise "Wrong arity. " + signature_error unless args.length == 1 or args.length == 2
		
		
		
		case args.length
			when 1
				if klass.is_a? Point
					self.inside_p *args
				elsif klass.is_a? Rectangle
					self.inside_r *args
				end
				
				# Will have exited by this point, unless there was an error.
				raise "One argument given. Expected Point or Rectangle, but recieved #{args[0].class.inspect} instead. " + signature_error
			when 2
				if args[0].class == args[1].class
					klass = args.first.class
					if klass.is_a? Point
						# a line, specified by two points
						self.inside_pp *args
					elsif klass.is_a? Float
						# a point in space, specified by two floats
						self.inside_xy *args 
					end
				end
				
				# Will have exited by this point, unless there was an error.
				raise "Two arguments given. Expected both to be Point or both to be Float, but recieved #{[args[0].class, args[1].class].inspect} instead. " + signature_error
		end
	end
	
	
	def intersects?(*args)
		signature_error = "Specify a line(two Point) or a rectangle(one Rectangle)."
		
		raise "Wrong arity. " + signature_error unless args.length == 1 or args.length == 2
		
		
		case args.length
			when 1
				raise "Expected a Rectangle, but recieved #{args[0].class.inspect} instead. " + signature_error unless args[0].is_a? Rectangle
				
				self.intersects_r *args
				
			when 2
				raise "Expected two Point objects, but recieved #{[args[0].class, args[1].class].inspect} instead. " + signature_error unless args.all?{ |a| a.is_a? Point } 
				
				self.intersects_pp *args
		end
	end
	
	
	alias :intersect? :intersects?
end

class Texture
	# TODO: clean up the interface for 'draw_wh' and 'draw_pt' bound from C++ layer
	# TODO: perhaps bind other methods of Texture?
	# TODO: consider binding Image as well, so you can CPU and GPU level control from Ruby
	
	# TODO: figure out exactly how the texure memory is being allocated (pick it appart later)
	# TODO: look into texture-atlasing for sprites, in the sprite-drawing libraries
	
	# TODO: figure out how textures can be used with mesh data
end

class Fbo
	private :draw_xy, :draw_xywh
	
	def draw(x,y, w=0,h=0)
		if w == 0 or h ==0
			draw_xy(x,y)
		else
			draw_xywh(x,y,w,h)
		end
	end
	
	Settings = Struct.new(
		:width,
		:height,
		:numColorbuffers,
		
		:useDepth,
		:useStencil,
		:depthStencilAsTexture,
		:textureTarget,
		:internalformat,
		:depthStencilInternalFormat,
		:wrapModeHorizontal,
		:wrapModeVertical,
		:minFilter,
		:maxFilter,
		:numSamples
	)
	# NOTE: While in OpenGL the names are "min" and "mag"
	#       (as in magnify)
	#       there seems to be a 'typo' of sorts in OpenFrameworks,
	#       so the proper name for this field is 'mag'
	# There is a function called ofTextureSetMinMagFilters() though.
end


# TODO: split all of these classes into separate files
# TODO: move 'test' file into the bin/ directory
# TODO: find some test sprites that can be used to make sure rendering is working (commit them)

# TODO: bind C++ functions to toggle vsync
# TODO: bind graphics functions with typedef instead of the wrapper style. would make it cleaer that the functions are working with global state, and are not actually bound to the window


# class Animation
# 	class Track
# 		def playing?
# 			return !ended?
# 		end
# 	end
# end




# class TrueTypeFont
	
# 	# private :load_from_struct
# 	def foo(data)
		
# 		# convert symbol into integer position,
# 		# and then convert position into the actual struct.
		
# 		i = UnicodeRanges.index(:Latin)
# 		struct = bar(i)
# 		settings.addRange(struct)
		
# 		self.load_from_struct(i)
# 	end
# end

class TtfSettings
	UnicodeRanges = [
		:Space,
		:Latin,
		:Latin1Supplement,
		:Greek,
		:Cyrillic,
		:Arabic,
		:ArabicSupplement,
		:ArabicExtendedA,
		:Devanagari,
		:HangulJamo,
		:VedicExtensions,
		:LatinExtendedAdditional,
		:GreekExtended,
		:GeneralPunctuation,
		:SuperAndSubScripts,
		:CurrencySymbols,
		:LetterLikeSymbols,
		:NumberForms,
		:Arrows,
		:MathOperators,
		:MiscTechnical,
		:BoxDrawing,
		:BlockElement,
		:GeometricShapes,
		:MiscSymbols,
		:Dingbats,
		:Hiragana,
		:Katakana,
		:HangulCompatJamo,
		:KatakanaPhoneticExtensions,
		:CJKLettersAndMonths,
		:CJKUnified,
		:DevanagariExtended,
		:HangulExtendedA,
		:HangulSyllables,
		:HangulExtendedB,
		:AlphabeticPresentationForms,
		:ArabicPresFormsA,
		:ArabicPresFormsB,
		:KatakanaHalfAndFullwidthForms,
		:KanaSupplement,
		:RumiNumericalSymbols,
		:ArabicMath,
		:MiscSymbolsAndPictographs,
		:Emoticons,
		:TransportAndMap
	]
	
	UnicodeAlphabets = [
		:Emoji,
		:Japanese,
		:Chinese,
		:Korean,
		:Arabic,
		:Devanagari,
		:Latin,
		:Greek,
		:Cyrillic
	]
	
	private :add_ranges
	private :add_range
	
	# Given a symbol from the UnicodeRanges list,
	# convert that to a numerical index.
	# 
	# On the C++ side, that number will be converted to the actual
	# range needed by the font system.
	def add_unicode_range(range_name)
		i = UnicodeRanges.index(range_name)
		add_range(i)
	end
	
	
	alias :cpp_add_alphabet :add_alphabet
	def add_alphabet(alphabet_name)
		i = UnicodeAlphabets.index(alphabet_name)
		cpp_add_alphabet(i)
	end
end





end


# TODO: move this to another file, so if you're not using Chipmunk, that's fine.
module CP
	class Vec2
		def to_ofPoint
			return RubyOF::Point.new(self.x, self.y, 0)
		end
	end
	
	class BB
		def to_ofRectangle
			raise "ERROR: Method is stubbed."
			# return RubyOF::Rectangle.new()
		end
	end
end
