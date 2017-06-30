#pragma once


#include "ofTrueTypeFont.h"
#include "rice.h"

Rice::Class Init_rubyOF_trueTypeFont(Rice::Module rb_mRubyOF);

void ofTrueTypeFont_load_from_struct(ofTrueTypeFont& font, Rice::Object rb_settings);

void ofTtfSettings_setFontName(ofTtfSettings& settings, std::string name);
std::string ofTtfSettings_getFontName(const ofTtfSettings& settings);

void ofTtfSettings_setFontSize(ofTtfSettings& settings, int size);
int ofTtfSettings_getFontSize(const ofTtfSettings& settings);

void ofTtfSettings_setAntialiased(ofTtfSettings& settings, bool aa);
bool ofTtfSettings_isAntialiased(const ofTtfSettings& settings);



void ofTtfSettings_addRanges(ofTtfSettings& settings, Rice::Object rb_range_list);
void ofTtfSettings_addRange(ofTtfSettings& settings, Rice::Object rb_range_index);


const ofUnicode::range ALL_UNICODE_RANGES[] = {
	ofUnicode::Space,
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
	ofUnicode::TransportAndMap
};
