#include "TrueTypeFont.h"


const ofUnicode::range ALL_UNICODE_RANGES[] = {
	ofUnicode::Space,
	ofUnicode::IdeographicSpace,
	ofUnicode::Latin,
	ofUnicode::Latin1Supplement,
	ofUnicode::Greek,
	ofUnicode::Cyrillic,
	ofUnicode::Arabic,
	ofUnicode::ArabicSupplement,
	ofUnicode::ArabicExtendedA,
	ofUnicode::Devanagari,
	ofUnicode::HangulJamo,
	ofUnicode::VedicExtensions,
	ofUnicode::LatinExtendedAdditional,
	ofUnicode::GreekExtended,
	ofUnicode::GeneralPunctuation,
	ofUnicode::SuperAndSubScripts,
	ofUnicode::CurrencySymbols,
	ofUnicode::LetterLikeSymbols,
	ofUnicode::NumberForms,
	ofUnicode::Arrows,
	ofUnicode::MathOperators,
	ofUnicode::MiscTechnical,
	ofUnicode::BoxDrawing,
	ofUnicode::BlockElement,
	ofUnicode::GeometricShapes,
	ofUnicode::MiscSymbols,
	ofUnicode::Dingbats,
	ofUnicode::Hiragana,
	ofUnicode::Katakana,
	ofUnicode::HangulCompatJamo,
	ofUnicode::KatakanaPhoneticExtensions,
	ofUnicode::CJKLettersAndMonths,
	ofUnicode::CJKUnified,
	ofUnicode::DevanagariExtended,
	ofUnicode::HangulExtendedA,
	ofUnicode::HangulSyllables,
	ofUnicode::HangulExtendedB,
	ofUnicode::AlphabeticPresentationForms,
	ofUnicode::ArabicPresFormsA,
	ofUnicode::ArabicPresFormsB,
	ofUnicode::KatakanaHalfAndFullwidthForms,
	ofUnicode::KanaSupplement,
	ofUnicode::RumiNumericalSymbols,
	ofUnicode::ArabicMath,
	ofUnicode::MiscSymbolsAndPictographs,
	ofUnicode::Emoticons,
	ofUnicode::TransportAndMap,
	ofUnicode::EnclosedCharacters,
	ofUnicode::Uncategorized,
	ofUnicode::AdditionalEmoticons,
	ofUnicode::AdditionalTransportAndMap,
	ofUnicode::OtherAdditionalSymbols
};


const std::initializer_list<ofUnicode::range> ALL_UNICODE_ALPHABETS[] = {
	ofAlphabet::Emoji,
	ofAlphabet::Japanese,
	ofAlphabet::Chinese,
	ofAlphabet::Korean,
	ofAlphabet::Arabic,
	ofAlphabet::Devanagari,
	ofAlphabet::Latin,
	ofAlphabet::Greek,
	ofAlphabet::Cyrillic
};




void ofTtfSettings_setFontName(ofTrueTypeFontSettings& settings, std::string name)
{
	settings.fontName = name;
}

std::string ofTtfSettings_getFontName(const ofTrueTypeFontSettings& settings){
	return settings.fontName.string();
}

void ofTtfSettings_setFontSize(ofTrueTypeFontSettings& settings, int size)
{
	settings.fontSize = size;
}

int ofTtfSettings_getFontSize(const ofTrueTypeFontSettings& settings){
	return settings.fontSize;
}

void ofTtfSettings_setAntialiased(ofTrueTypeFontSettings& settings, bool aa){
	settings.antialiased = aa;
}

bool ofTtfSettings_isAntialiased(const ofTrueTypeFontSettings& settings){
	return settings.antialiased;
}




// TODO: Implement this.
void ofTtfSettings_addRanges(ofTrueTypeFontSettings& settings, Rice::Object rb_range_list){
	// settings.addRanges();
}

void ofTtfSettings_addRange(ofTrueTypeFontSettings& settings, Rice::Object rb_range_index){
	
	Rice::Object tmp_obj = rb_range_index;
	int i = tmp_obj.is_nil() ? -1 : from_ruby<int>(tmp_obj);
	ofUnicode::range rng = ALL_UNICODE_RANGES[i];
	
	settings.addRange(rng);
}

// NOTE: This is custom (not in the main OpenFrameworks API)
void ofTtfSettings_addAlphabet(ofTrueTypeFontSettings& settings, Rice::Object rb_range_index){
	
	Rice::Object tmp_obj = rb_range_index;
	int i = tmp_obj.is_nil() ? -1 : from_ruby<int>(tmp_obj);
	
	std::initializer_list<ofUnicode::range> rngs = ALL_UNICODE_ALPHABETS[i];
	settings.addRanges(rngs);
}


using namespace Rice;

Rice::Class Init_rubyOF_trueTypeFont(Rice::Module rb_mRubyOF)
{
	Data_Type<ofTrueTypeFont> rb_cTrueTypeFont = 
		define_class_under<ofTrueTypeFont>(rb_mRubyOF, "TrueTypeFont");
	
	// typedef ofTrueTypeFont (ofTrueTypeFont::*constructTrueTypeFont)();
	
	rb_cTrueTypeFont
		.define_constructor(Constructor<ofTrueTypeFont>())
		.define_method("load",
			static_cast<bool (ofTrueTypeFont::*)
			(const ofTrueTypeFontSettings&)
			>(&ofTrueTypeFont::load)
		)
		.define_method("draw_string",      &ofTrueTypeFont::drawString)
		
		.define_method("string_width",     &ofTrueTypeFont::stringWidth)
		.define_method("string_height",    &ofTrueTypeFont::stringHeight)
		.define_method("string_bb",        &ofTrueTypeFont::getStringBoundingBox)
		// ^ need to bind the ofRectangle type before this will work correctly
		
		.define_method("size",             &ofTrueTypeFont::getSize)
		.define_method("line_height=",     &ofTrueTypeFont::setLineHeight)
		.define_method("line_height",      &ofTrueTypeFont::getLineHeight)
		.define_method("ascender_height",  &ofTrueTypeFont::getAscenderHeight)
		.define_method("descender_height", &ofTrueTypeFont::getDescenderHeight)
		.define_method("letter_spacing",   &ofTrueTypeFont::getLetterSpacing)
		.define_method("letter_spacing=",  &ofTrueTypeFont::setLetterSpacing)
		.define_method("space_size",       &ofTrueTypeFont::getSpaceSize)
		.define_method("space_size=",      &ofTrueTypeFont::setSpaceSize)
		// .define_method("getKerning",       &ofTrueTypeFont::getKerning)
			// compile error:
			// "error: ‘int ofTrueTypeFont::getKerning(int, int) const’ is protected"
		
		.define_method("antialiased?",     &ofTrueTypeFont::isAntiAliased)
		
		
		
		.define_method("get_string_mesh",  &ofTrueTypeFont::getStringMesh)
		// Returns the string as an ofMesh. Note: this is a mesh that contains vertices and texture coordinates for the textured font, not the points of the font that are returned via any of the get points functions.
		// src: OpenFrameworks documentation
		// 
		// This mesh is just bounding boxes for each and every character.
		
		.define_method("font_texture",     &ofTrueTypeFont::getFontTexture)
		// This is the texture associated with the mesh above
	;
	
	
	
	
	Data_Type<ofTrueTypeFontSettings> rb_cTrueTypeFontSettings = 
		define_class_under<ofTrueTypeFontSettings>(rb_mRubyOF, "TrueTypeFontSettings");
	
	rb_cTrueTypeFontSettings
		.define_constructor(Constructor<ofTrueTypeFontSettings, const std::string, int>())
		.define_method("font_name",       &ofTtfSettings_getFontName)
		.define_method("font_name=",      &ofTtfSettings_setFontName)
		.define_method("font_size",       &ofTtfSettings_getFontSize)
		.define_method("font_size=",      &ofTtfSettings_setFontSize)
		
		.define_method("antialiased?",    &ofTtfSettings_isAntialiased)
		.define_method("antialiased=",    &ofTtfSettings_setAntialiased)
		
		.define_method("add_ranges",      &ofTtfSettings_addRanges)
		.define_method("add_range",       &ofTtfSettings_addRange)
		
		.define_method("add_alphabet",    &ofTtfSettings_addAlphabet)
	;
	
	
	
	
	return rb_cTrueTypeFont;
}



 //    std::filesystem::path fontName;
	// int fontSize;
	// bool antialiased = true;
	// bool contours = false;
	// float simplifyAmt = 0.3f;
	// int dpi = 0;

	// enum Direction{
	// 	LeftToRight,
	// 	RightToLeft
	// };
	// Direction direction = LeftToRight;

	// void addRanges(std::initializer_list<ofUnicode::range> alphabet){
	// 	ranges.insert(ranges.end(), alphabet);
	// }

	// void addRange(const ofUnicode::range & range){
	// 	ranges.push_back(range);
	// }

