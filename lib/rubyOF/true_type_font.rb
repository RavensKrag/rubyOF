# NOTE: SelfMonkeyPatch is a module that holds monkey patches that were created to define core behavior at the ruby level, instead of having to write C / C++.

module RubyOF
	module SelfMonkeyPatch


# This extension to the base font class allows you
# to read the name off the font object,
# without having to keep the settings object alive.
# All other properties of the font can be read
# through the font object, but not the name.
# It appears that the name is not even being set
# as a member variable on the font object.

# TODO: file bug report for ofTrueTypeFont, stating that name can not be retrieved from the font object, only the settings object.
module TrueTypeFont
	def load(settings)
		@settings = settings
		flag = super(settings)
		unless flag
			raise "ERROR: Could not load font #{@settings.font_name}"
		end
	end
	
	def name
		@settings.font_name
	end
	
	# Return the font name as specified by the settings object
	# (in some cases, this may actually be the full path to the font file)
	# 
	# (Currently, this is the indentifier of the font file, and not actually the 'name' of the font face.)
	def name
		raise "ERROR: Font not yet loaded." if @name.nil?
		# ^ @name not set until #load() is called.
		
		return @name
	end
	# NOTE: no setter for this value, because you can't change the font face once the font object is loaded. (have to switch objects)
end


end; end
# --- end monkey patches



module RubyOF

class TrueTypeFont
	# The actual definition is above, but we want to use clean monkey patching
	# (https://stackoverflow.com/questions/4470108/when-monkey-patching-a-method-can-you-call-the-overridden-method-from-the-new-i)
	
	prepend RubyOF::SelfMonkeyPatch::TrueTypeFont
	
	
	# # private :load_from_struct
	# def foo(data)
		
	# 	# convert symbol into integer position,
	# 	# and then convert position into the actual struct.
		
	# 	i = UnicodeRanges.index(:Latin)
	# 	struct = bar(i)
	# 	settings.addRange(struct)
		
	# 	self.load_from_struct(i)
	# end
	
	
	# Create easy gemfile-style DSL for loading font parameters,
	# including error checking.
	class << self
		def dsl_load # &block
			config = DSL_Object.new
			
			yield config
			
			
			font_settings = RubyOF::TrueTypeFontSettings.new(config.path, config.size)
			
			config.alphabets.each do |x|
				font_settings.add_alphabet x
			end
			
			
			
			puts "loading font"
			font = RubyOF::ResourceManager.instance.load font_settings
			# ^ will throw exception if font can not be loaded
			
			return font
		end
	end
	
	class DSL_Object
		attr_reader :alphabets
		attr_accessor :path, :size, :antialiased
		
		def initialize
			@alphabets = Array.new
		end
		
		def add_alphabet(alphabet)
			alphabet_list = RubyOF::TrueTypeFontSettings::UnicodeAlphabets
			unless alphabet_list.include? alphabet
				message = [
					"Alphabet '#{alphabet}' is not one of the supported values.",
					"Use a value from TrueTypeFontSettings::UnicodeAlphabets",
					"Try one of these: #{alphabet_list.inspect}"
				].join("\n")
				
				raise message
			end
			
			@alphabets << alphabet
		end
	end
end

class TrueTypeFontSettings
	UnicodeRanges = [
		:Space,
		:IdeographicSpace,
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
		:TransportAndMap,
		:EnclosedCharacters,
		:Uncategorized,
		:AdditionalEmoticons,
		:AdditionalTransportAndMap,
		:OtherAdditionalSymbols
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
		@ranges ||= Array.new
		@ranges << range_name
		i = UnicodeRanges.index(range_name)
		add_range(i)
	end
	
	
	alias :cpp_add_alphabet :add_alphabet
	def add_alphabet(alphabet_name)
		@alphabets ||= Array.new
		@alphabets << alphabet_name
		i = UnicodeAlphabets.index(alphabet_name)
		cpp_add_alphabet(i)
	end
	
	
	
	
	def ==(other)
		return true if other.equal?(self)
		return false unless other.instance_of?(self.class)
		
		
		return  (self.font_name == other.font_name &&
		         self.font_size == other.font_size &&
		         self.antialiased? == other.antialiased? &&
		         @ranges == other.instance_variable_get('@ranges') &&
		         @alphabets == other.instance_variable_get('@alphabets') )
	end
	
	
	
	# Need to implement both eql? and hash to use this class as Hash key
	# Resource manager needs to be able to use TrueTypeFontSettings as a key.
	def eql?(other)
		# by default this is the same as ==\
		
		# The eql? method returns true if obj and anObject have the same value. Used by Hash to test members for equality. For objects of class Object, eql? is synonymous with ==. Subclasses normally continue this tradition, but there are exceptions. Numeric types, for example, perform type conversion across ==, but not across eql?
		# src: http://ruby-doc.org/core-1.9.3/Object.html#method-i-eql-3F
		
		self == other
	end
	
	def hash
		[
			self.font_name,
			self.font_size,
			self.antialiased?,
			@ranges,
			@alphabets
		].hash
	end
end



end
