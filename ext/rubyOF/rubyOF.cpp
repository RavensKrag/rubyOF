#include "rubyOF.h"

#include <iostream>

// === C++ stuff
#include "launcher.h"

// === Rice glue code
// #include "Window.h" 
// ===== re-enable this asap =====
// #include "Graphics.h"
// #include "Fbo.h"
// #include "TrueTypeFont.h"
// ===== re-enable this asap =====

// === Additional OpenFrameworks types
// #include "ofApp.h"
// #include "ofAppRunner.h"
// #include "ofFbo.h"


using namespace Rice;

extern "C"
void Init_rubyOF()
{
	std::cout << "c++: set up module: RubyOF\n";
	Module rb_mRubyOF = define_module("RubyOF");
	
	// ===== re-enable this asap =====
	// Init_rubyOF_graphics(rb_mRubyOF);
	// Init_rubyOF_fbo(rb_mRubyOF);
	// Init_rubyOF_trueTypeFont(rb_mRubyOF);
	// ===== re-enable this asap =====
	
	// ofPoint is the same as ofVec3
	Data_Type<ofPoint> rb_cPoint =
		define_class_under<ofPoint>(rb_mRubyOF, "Point");
	
	rb_cPoint
		.define_constructor(Constructor<ofPoint, float, float, float>())
		.define_method("get_component",   &ofVec3f_get_component)
		.define_method("set_component",   &ofVec3f_set_component)
	;
	
	
	// TODO: wrap the GLM vectors, and operation on those types.
	// oF is transitioning to using GLM vector / math types, rather than rolling their own system. This is super cool to me, but involves re-wrapping a bunch of stuff. Expect weird breakages.
	
	
	// TODO: Wrap font loading and texture loading in a manner similar to the FBO loading system: assume data comes in via a Ruby object, and convert to the necessary C++ struct or w/e, and then send that data to the C++ call.
	
	// TODO: move different things to different files. way to crouded in here
	
	
	
	Data_Type<Launcher> rb_cWindow =
		define_class_under<Launcher>(rb_mRubyOF, "Window");
	
	rb_cWindow
		.define_constructor(Constructor<Launcher, Rice::Object, int, int>())
		// .define_method("initialize", &Launcher::initialize)
		.define_method("show",   &Launcher::show)
		.define_method("ofExit", &ofExit,
			(
				Arg("status") = 0
			)
		)
		
		.define_method("width",       &ofGetWidth)
		.define_method("height",       &ofGetHeight)
		
		// mouse cursor
		.define_method("show_cursor",       &Launcher::showCursor)
		.define_method("hide_cursor",       &Launcher::hideCursor)
		
		// fullscreen
		.define_method("fullscreen",         &Launcher::setFullscreen)
		.define_method("toggle_fullscreen",  &Launcher::toggleFullscreen)
		
		// window properties
		.define_method("window_title=",       &Launcher::setWindowTitle)
		.define_method("set_window_position", &Launcher::setWindowPosition)
		.define_method("set_window_shape",    &Launcher::setWindowShape)
		.define_method("window_position",     &Launcher::getWindowPosition)
		.define_method("window_size",         &Launcher::getWindowSize)
		.define_method("screen_size",         &Launcher::getScreenSize)
		// .define_method("set_window_icon",     &Launcher::setWindowIcon) // private C++ method
		
		
		// timing and framerate
		.define_method("ofGetLastFrameTime", &ofGetLastFrameTime)
		.define_method("ofGetFrameRate",     &ofGetFrameRate)
		.define_method("ofSetFrameRate",     &ofSetFrameRate)
		
		
		// clipboard support
		.define_method("clipboard_string=",   &Launcher::setClipboardString)
		.define_method("clipboard_string",    &Launcher::getClipboardString)
		
		
		.define_method("ofSetEscapeQuitsApp", &ofSetEscapeQuitsApp)
	;
	
	
	
	Data_Type<ofRectangle> rb_cRectangle = 
		define_class_under<ofRectangle>(rb_mRubyOF, "Rectangle");
	
	
	typedef bool (ofRectangle::*ofRectangle_test_xy)(float px, float py) const;
	typedef bool (ofRectangle::*ofRectangle_test_p)(const glm::vec3& p) const;
	typedef bool (ofRectangle::*ofRectangle_test_r)(const ofRectangle& rect) const;
	typedef bool (ofRectangle::*ofRectangle_test_pp)(const glm::vec3& p0, const glm::vec3& p1) const;
	
	
	rb_cRectangle
		.define_constructor(Constructor<ofRectangle>())
		.define_method("center", &ofRectangle::getCenter)
		.define_method("x",      &ofRectangle::getX)
		.define_method("y",      &ofRectangle::getY)
		
		.define_method("left",   &ofRectangle::getLeft)
		.define_method("right",  &ofRectangle::getRight)
		.define_method("bottom", &ofRectangle::getBottom)
		.define_method("top",    &ofRectangle::getTop)
		
		.define_method("width",        &ofRectangle::getWidth)
		.define_method("height",       &ofRectangle::getHeight)
		.define_method("area",         &ofRectangle::getArea)
		.define_method("perimeter",    &ofRectangle::getPerimeter)
		.define_method("aspect_ratio", &ofRectangle::getAspectRatio)
		
		/// \brief Get the union area between this rectangle and anohter.
		///
		/// \sa growToInclude(const ofRectangle& rect)
		/// \param rect The rectangle to unite with.
		/// \returns A new ofRectangle whose area contains both the area of the
		///          this rectangle and the passed rectangle..
		.define_method("union",   &ofRectangle::getUnion)
		
		// Rectangles can visually be the same, but have different numerical values.
		// However, when transformed, rects with different values will be different.
		// This can be a major point of confusion. To avoid this, convert rects to standard form.
		.define_method("standardize",   &ofRectangle::standardize)
		.define_method("standardized",  &ofRectangle::getStandardized)
		.define_method("standardized?", &ofRectangle::isStandardized)
		
		// .define_method("intersects?",   &ofRectangle::intersects)
		
		.define_method("inside_xy",   ofRectangle_test_xy(&ofRectangle::inside))
		.define_method("inside_p",    ofRectangle_test_p(&ofRectangle::inside))
		.define_method("inside_r",    ofRectangle_test_r(&ofRectangle::inside))
		.define_method("inside_pp",   ofRectangle_test_pp(&ofRectangle::inside))
		
		.define_method("intersects_r",    ofRectangle_test_r(&ofRectangle::intersects))
		.define_method("intersects_pp",   ofRectangle_test_pp(&ofRectangle::intersects))
	;
	// NOTE: ofRectangle has a lot of logic for aligning rectangular shapes. Could be useful.
	
	
	
    
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	// NOTE: There is an interface for specifying colors in HSB space, but they are always stored in RGB space.
	Data_Type<ofColor> rb_cColor = 
		define_class_under<ofColor>(rb_mRubyOF, "Color");
	
	// typedef void (ofColor::*ofColor_allocWRAP)(int,int,int,int) const;
	
	// typedef void (ofColor::*ofColor_draw)(float x, float y) const;
	// typedef void (ofColor::*ofColor_draw_wh)(float x, float y, float width, float height) const;
	
	rb_cColor
		.define_constructor(Constructor<ofColor>())
		
		.define_method("set_hex",  &ofColor::setHex)
		.define_method("set_hsb",  &ofColor::setHsb)
		
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
	
	
	
 //    /// \brief Set an ofColor_ by using channel values.
 //    ///
 //    /// When modifying an instance of ofColor_ the channel values must fall
 //    /// within the range represented by the PixelType.  By default, the alpha
 //    /// component will take the PixelType's maximum, producing an opaque color.
 //    ///
 //    /// ~~~~{.cpp}
 //    ///     ofColor c(255, 0, 0); // Red ...
 //    ///     c.set(0, 255, 0); // ... and now green.
 //    /// ~~~~
 //    ///
 //    /// \param red The red component.
 //    /// \param green The green component.
 //    /// \param blue The blue component.
 //    /// \param alpha The alpha component.
 //    void set(float red, float green, float blue, float alpha = limit());

	
	
	
	
	
	
	
	
	
	// ofTexture
	// ofImage
	// ofPixels
	
	Data_Type<ofTexture> rb_cTexture = 
		define_class_under<ofTexture>(rb_mRubyOF, "Texture");
	
	
	
	typedef void (ofTexture::*ofTexture_draw_wh)(float x, float y, float z, float w, float h) const;
	typedef void (ofTexture::*ofTexture_draw_pt)(const glm::vec3 & p1, const glm::vec3 & p2, const glm::vec3 & p3, const glm::vec3 & p4) const;
	
	rb_cTexture
		.define_constructor(Constructor<ofTexture>())
		.define_method("draw_wh",   ofTexture_draw_wh(&ofTexture::draw))
		.define_method("draw_pt",   ofTexture_draw_pt(&ofTexture::draw))
	;
	
	// void draw(float x, float y, float z, float w, float h) const;
	// void draw(const ofPoint & p1, const ofPoint & p2, const ofPoint & p3, const ofPoint & p4) const;
	// void drawSubsection // <-- many different interfaces. unsure which to bind
	
	
	typedef bool (*load_image_from_file)(ofTexture & tex, const std::filesystem::path& path, const ofImageLoadSettings &settings);
	
	
	rb_cWindow
		// textures
		.define_method("ofLoadImage", load_image_from_file(&ofLoadImage))
	;
	
	
	
	Rice::Module rb_cUtils = 
		define_module_under(rb_mRubyOF, "Utils");
	
	rb_cUtils
		.define_module_function("ofGetElapsedTimeMicros",   &ofGetElapsedTimeMicros)
		.define_module_function("ofGetElapsedTimeMillis",   &ofGetElapsedTimeMillis)
		.define_module_function("ofGetElapsedTimef",        &ofGetElapsedTimef)
		.define_module_function("ofGetFrameNum",            &ofGetFrameNum)
	;
}


float ofVec3f_get_component(ofPoint& p, int i){
	return p[i];
}

void  ofVec3f_set_component(ofPoint& p, int i, float value){
	p[i] = value;
}

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

// VALUE klass = rb_define_class_under(outer, "Window", rb_cObject);
