#include "Color.h"

using namespace Rice;


// 
// ofColor
// ofColor_<unsigned char>
// 

int  ofColor_getRed(ofColor& color){
	return color.r;
}

int  ofColor_getGreen(ofColor& color){
	return color.g;
}

int  ofColor_getBlue(ofColor& color){
	return color.b;
}

int  ofColor_getAlpha(ofColor& color){
	return color.a;
}

void ofColor_setRed(ofColor& color, int value){
	color.r = value;
}

void ofColor_setGreen(ofColor& color, int value){
	color.g = value;
}

void ofColor_setBlue(ofColor& color, int value){
	color.b = value;
}

void ofColor_setAlpha(ofColor& color, int value){
	color.a = value;
}

// 
// ofFloatColor
// ofColor_<float>
// 

float  ofFloatColor_getRed(ofFloatColor& color){
	return color.r;
}

float  ofFloatColor_getGreen(ofFloatColor& color){
	return color.g;
}

float  ofFloatColor_getBlue(ofFloatColor& color){
	return color.b;
}

float  ofFloatColor_getAlpha(ofFloatColor& color){
	return color.a;
}

void ofFloatColor_setRed(ofFloatColor& color, float value){
	color.r = value;
}

void ofFloatColor_setGreen(ofFloatColor& color, float value){
	color.g = value;
}

void ofFloatColor_setBlue(ofFloatColor& color, float value){
	color.b = value;
}

void ofFloatColor_setAlpha(ofFloatColor& color, float value){
	color.a = value;
}

// 
// ofShortColor
// ofColor_<unsigned short>
// 

int  ofShortColor_getRed(ofShortColor& color){
	return color.r;
}

int  ofShortColor_getGreen(ofShortColor& color){
	return color.g;
}

int  ofShortColor_getBlue(ofShortColor& color){
	return color.b;
}

int  ofShortColor_getAlpha(ofShortColor& color){
	return color.a;
}

void ofShortColor_setRed(ofShortColor& color, int value){
	color.r = value;
}

void ofShortColor_setGreen(ofShortColor& color, int value){
	color.g = value;
}

void ofShortColor_setBlue(ofShortColor& color, int value){
	color.b = value;
}

void ofShortColor_setAlpha(ofShortColor& color, int value){
	color.a = value;
}




void Init_rubyOF_Color(Rice::Module rb_mRubyOF){
	
	// NOTE: There is an interface for specifying colors in HSB space, but they are always stored in RGB space.
	Data_Type<ofColor> rb_cColor = 
		define_class_under<ofColor>(rb_mRubyOF, "Color");
	
	// the default ofColor is ofColor_<unsigned char> 
	// but the color required by Light is ofColor_<float>
	
	rb_cColor
		.define_constructor(Constructor<ofColor>())
		
		
		// WARNING: set_hex does not pack alpha channel
		//          alpha must be specified as a separate argument
		.define_method("set_hex",  &ofColor::setHex,
			(
				Arg("hexColor"),
				Arg("alpha") = 255
			)
		)
		.define_method("set_hsb",  &ofColor::setHsb)
		
		// WARNING: get_hex does not include alpha
		.define_method("get_hex",  &ofColor::getHex)
		.define_method("get_hsb",  &ofColor::getHsb)
		
		
    	// from ofColor.h:
	    /// Brightness is simply the maximum of the three color components. This
	    /// method of calculating brightness is used by Photoshop (HSB) and
	    /// Processing (HSB).  Note that brightness is also called "Value".
	    // 
	    /// Lightness is simply the average of the three color components. This
	    /// method of calculating lightness is used by the Lab and HSL color spaces.
		
		
		// rgb color space manipluation (direct manipulation of the struct)
		.define_method("r=",  &ofColor_setRed)
		.define_method("g=",  &ofColor_setGreen)
		.define_method("b=",  &ofColor_setBlue)
		.define_method("a=",  &ofColor_setAlpha)
		
		.define_method("r",   &ofColor_getRed)
		.define_method("g",   &ofColor_getGreen)
		.define_method("b",   &ofColor_getBlue)
		.define_method("a",   &ofColor_getAlpha)
		
		// hsb color space manipulation (indirect manipulation)
		.define_method("hue=",         &ofColor::setHue)
		.define_method("hue_angle=",   &ofColor::setHueAngle)
		.define_method("saturation=",  &ofColor::setSaturation)
		.define_method("brightness=",  &ofColor::setBrightness)
		
		.define_method("hue",          &ofColor::getHue)
		.define_method("hue_angle",    &ofColor::getHueAngle)
		.define_method("saturation",   &ofColor::getSaturation)
		.define_method("brightness",   &ofColor::getBrightness)
		.define_method("lightness",    &ofColor::getLightness)
	;
	
	
	
	
	
	
	
	
	
	Data_Type<ofFloatColor> rb_cFloatColor = 
		define_class_under<ofFloatColor>(rb_mRubyOF, "FloatColor");
	
	// the default ofColor is ofColor_<unsigned char> 
	// but the color required by Light is ofColor_<float>
	
	rb_cFloatColor
		.define_constructor(Constructor<ofFloatColor>())
		
		
		// WARNING: set_hex does not pack alpha channel
		//          alpha must be specified as a separate argument
		.define_method("set_hex",  &ofFloatColor::setHex,
			(
				Arg("hexColor"),
				Arg("alpha") = 255
			)
		)
		.define_method("set_hsb",  &ofFloatColor::setHsb)
		
		// WARNING: get_hex does not include alpha
		.define_method("get_hex",  &ofFloatColor::getHex)
		.define_method("get_hsb",  &ofFloatColor::getHsb)
		
		
		
		// rgb color space manipluation (direct manipulation of the struct)
		.define_method("r=",  &ofFloatColor_setRed)
		.define_method("g=",  &ofFloatColor_setGreen)
		.define_method("b=",  &ofFloatColor_setBlue)
		.define_method("a=",  &ofFloatColor_setAlpha)
		
		.define_method("r",   &ofFloatColor_getRed)
		.define_method("g",   &ofFloatColor_getGreen)
		.define_method("b",   &ofFloatColor_getBlue)
		.define_method("a",   &ofFloatColor_getAlpha)
		
		// hsb color space manipulation (indirect manipulation)
		.define_method("hue=",         &ofFloatColor::setHue)
		.define_method("hue_angle=",   &ofFloatColor::setHueAngle)
		.define_method("saturation=",  &ofFloatColor::setSaturation)
		.define_method("brightness=",  &ofFloatColor::setBrightness)
		
		.define_method("hue",          &ofFloatColor::getHue)
		.define_method("hue_angle",    &ofFloatColor::getHueAngle)
		.define_method("saturation",   &ofFloatColor::getSaturation)
		.define_method("brightness",   &ofFloatColor::getBrightness)
		.define_method("lightness",    &ofFloatColor::getLightness)
	;
	
	
	
	
	
	
	
	Data_Type<ofShortColor> rb_cShortColor = 
		define_class_under<ofShortColor>(rb_mRubyOF, "ShortColor");
	
	// the default ofColor is ofColor_<unsigned char> 
	// but the color required by Light is ofColor_<float>
	
	rb_cShortColor
		.define_constructor(Constructor<ofShortColor>())
		
		
		// WARNING: set_hex does not pack alpha channel
		//          alpha must be specified as a separate argument
		.define_method("set_hex",  &ofShortColor::setHex,
			(
				Arg("hexColor"),
				Arg("alpha") = 255
			)
		)
		.define_method("set_hsb",  &ofShortColor::setHsb)
		
		// WARNING: get_hex does not include alpha
		.define_method("get_hex",  &ofShortColor::getHex)
		.define_method("get_hsb",  &ofShortColor::getHsb)
		
		
		
		// rgb color space manipluation (direct manipulation of the struct)
		.define_method("r=",  &ofShortColor_setRed)
		.define_method("g=",  &ofShortColor_setGreen)
		.define_method("b=",  &ofShortColor_setBlue)
		.define_method("a=",  &ofShortColor_setAlpha)
		
		.define_method("r",   &ofShortColor_getRed)
		.define_method("g",   &ofShortColor_getGreen)
		.define_method("b",   &ofShortColor_getBlue)
		.define_method("a",   &ofShortColor_getAlpha)
		
		// hsb color space manipulation (indirect manipulation)
		.define_method("hue=",         &ofShortColor::setHue)
		.define_method("hue_angle=",   &ofShortColor::setHueAngle)
		.define_method("saturation=",  &ofShortColor::setSaturation)
		.define_method("brightness=",  &ofShortColor::setBrightness)
		
		.define_method("hue",          &ofShortColor::getHue)
		.define_method("hue_angle",    &ofShortColor::getHueAngle)
		.define_method("saturation",   &ofShortColor::getSaturation)
		.define_method("brightness",   &ofShortColor::getBrightness)
		.define_method("lightness",    &ofShortColor::getLightness)
	;
}
	
