module RubyOF

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
