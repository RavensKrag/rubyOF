#include "TrueTypeFont.h"

using namespace Rice;

Rice::Class Init_rubyOF_trueTypeFont(Rice::Module rb_mRubyOF)
{
	Data_Type<ofTrueTypeFont> rb_cTrueTypeFont = 
		define_class_under<ofTrueTypeFont>(rb_mRubyOF, "TrueTypeFont");
	
	// typedef ofTrueTypeFont (ofTrueTypeFont::*constructTrueTypeFont)();
	
	rb_cTrueTypeFont
		.define_constructor(Constructor<ofTrueTypeFont>())
		.define_method("load",
			static_cast<bool (ofTrueTypeFont::*)(const ofTtfSettings&)>(
				&ofTrueTypeFont::load
			)
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
	;
	
	
	
	
	Data_Type<ofTtfSettings> rb_cTtfSettings = 
		define_class_under<ofTtfSettings>(rb_mRubyOF, "TtfSettings");
	
	rb_cTtfSettings
		.define_constructor(Constructor<ofTtfSettings, const std::string, int>())
		.define_method("font_name",       &ofTtfSettings_getFontName)
		.define_method("font_name=",      &ofTtfSettings_setFontName)
		.define_method("font_size",       &ofTtfSettings_getFontSize)
		.define_method("font_size=",      &ofTtfSettings_setFontSize)
		
		.define_method("antialiased?",    &ofTtfSettings_isAntialiased)
		.define_method("antialiased=",    &ofTtfSettings_setAntialiased)
		
		.define_method("add_ranges",      &ofTtfSettings_addRanges)
		.define_method("add_range",       &ofTtfSettings_addRange)
	;
	
	
	
	
	return rb_cTrueTypeFont;
}

void ofTrueTypeFont_load_from_struct(
	ofTrueTypeFont& font,
	Rice::Object rb_settings
){
	
	
	
	ofTtfSettings settings("TakaoPGothic", 20); // This works fine
	settings.antialiased = true;
	settings.addRanges({
	    ofUnicode::Space,
	    ofUnicode::Latin1Supplement,
	    ofUnicode::LatinExtendedAdditional,
	    ofUnicode::Hiragana,
	    ofUnicode::Katakana,
	    ofUnicode::KatakanaPhoneticExtensions,
	    ofUnicode::CJKLettersAndMonths,
	    ofUnicode::CJKUnified,
	});
	
	
	font.load(settings);
}


void ofTtfSettings_setFontName(ofTtfSettings& settings, std::string name)
{
	settings.fontName = name;
}

std::string ofTtfSettings_getFontName(const ofTtfSettings& settings){
	return settings.fontName.string();
}

void ofTtfSettings_setFontSize(ofTtfSettings& settings, int size)
{
	settings.fontSize = size;
}

int ofTtfSettings_getFontSize(const ofTtfSettings& settings){
	return settings.fontSize;
}

void ofTtfSettings_setAntialiased(ofTtfSettings& settings, bool aa){
	settings.antialiased = aa;
}

bool ofTtfSettings_isAntialiased(const ofTtfSettings& settings){
	return settings.antialiased;
}




// TODO: Implement this.
void ofTtfSettings_addRanges(ofTtfSettings& settings, Rice::Object rb_range_list){
	// settings.addRanges();
}

void ofTtfSettings_addRange(ofTtfSettings& settings, Rice::Object rb_range_index){
	
	Rice::Object tmp_obj = rb_range_index;
	int i = tmp_obj.is_nil() ? -1 : from_ruby<int>(tmp_obj);
	ofUnicode::range rng = ALL_UNICODE_RANGES[i];
	
	settings.addRange(rng);
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



