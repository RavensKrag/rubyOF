#include "Color.h"

using namespace Rice;



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




void Init_rubyOF_Color(Rice::Module rb_mRubyOF){
	
	// NOTE: There is an interface for specifying colors in HSB space, but they are always stored in RGB space.
	Data_Type<ofColor> rb_cColor = 
		define_class_under<ofColor>(rb_mRubyOF, "Color");
	
	// typedef void (ofColor::*ofColor_allocWRAP)(int,int,int,int) const;
	
	// typedef void (ofColor::*ofColor_draw)(float x, float y) const;
	// typedef void (ofColor::*ofColor_draw_wh)(float x, float y, float width, float height) const;
	
	
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
}
	
