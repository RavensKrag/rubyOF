#include "rubyOF.h"

#include <iostream>

// === C++ stuff
#include "launcher.h"

// === Rice glue code
// #include "Window.h" 
#include "glm_bindings.h"
#include "Graphics.h"
#include "GraphicsAdvanced.h"
#include "Fbo.h"
#include "TrueTypeFont.h"
#include "Color.h"

// === Additional OpenFrameworks types
// #include "ofApp.h"
// #include "ofAppRunner.h"
// #include "ofFbo.h"


void ofWindow__setWindowPosition(ofAppGLFWWindow& window, glm::vec2 &pos){
	window.setWindowPosition(pos.x, pos.y);
}

using namespace Rice;

extern "C"
void Init_rubyOF()
{
	std::cout << "c++: set up module: GLM\n";
	Module rb_mGLM = Init_GLM();
	
	
	std::cout << "c++: set up module: RubyOF\n";
	Module rb_mRubyOF = define_module("RubyOF");
	
	Init_rubyOF_Color(rb_mRubyOF); // ofColor, ofFloatColor, and ofShortColor
	
	Rice::Module rb_mGraphics     = Init_rubyOF_graphics(rb_mRubyOF);    // immediate mode (slow)
	
	Init_rubyOF_GraphicsAdv(rb_mRubyOF); // retained mode  (fast)
	// ^ Includes: Mesh bindings
	
	Rice::Class  rb_cFbo          = Init_rubyOF_fbo(rb_mRubyOF);
	Rice::Class  rb_cTrueTypeFont = Init_rubyOF_trueTypeFont(rb_mRubyOF);
	
	
	
	// TODO: wrap the GLM vectors, and operation on those types.
	// oF is transitioning to using GLM vector / math types, rather than rolling their own system. This is super cool to me, but involves re-wrapping a bunch of stuff. Expect weird breakages.
	
	
	// TODO: Wrap font loading and texture loading in a manner similar to the FBO loading system: assume data comes in via a Ruby object, and convert to the necessary C++ struct or w/e, and then send that data to the C++ call.
	
	// TODO: move different things to different files. way to crouded in here
	
	
	
	Data_Type<Launcher> rb_cLauncher =
		define_class_under<Launcher>(rb_mRubyOF, "Launcher");
	
	rb_cLauncher
		.define_constructor(Constructor<Launcher, Rice::Object>())
		// .define_method("initialize", &Launcher::initialize)
		.define_method("show",   &Launcher::show)
	;
	
	
	Data_Type<ofAppGLFWWindow> rb_cWindow =
		define_class_under<ofAppGLFWWindow>(rb_mRubyOF, "Window");
	
	rb_cWindow
		// .define_constructor(Constructor<ofAppGLFWWindow>())
		// .define_method("initialize", &Window::initialize)
		
		// mouse cursor
		.define_method("show_cursor",       &ofAppGLFWWindow::showCursor)
		.define_method("hide_cursor",       &ofAppGLFWWindow::hideCursor)
		
		// fullscreen
		.define_method("fullscreen",         &ofAppGLFWWindow::setFullscreen)
		.define_method("toggle_fullscreen",  &ofAppGLFWWindow::toggleFullscreen)
		
		// window properties
		.define_method("width",               &ofGetWidth)
		.define_method("height",              &ofGetHeight)
		.define_method("title=",              &ofAppGLFWWindow::setWindowTitle)
		.define_method("position",            &ofAppGLFWWindow::getWindowPosition) // => glm::vec2
		.define_method("position=",           &ofWindow__setWindowPosition)
		.define_method("set_window_shape",    &ofAppGLFWWindow::setWindowShape)
		.define_method("window_size",         &ofAppGLFWWindow::getWindowSize) // => glm::vec2
		.define_method("screen_size",         &ofAppGLFWWindow::getScreenSize) // => glm::vec2
		
		.define_method("set_window_icon",     
			static_cast< void (ofAppGLFWWindow::*)
         (const std::string &path)
         >(&ofAppGLFWWindow::setWindowIcon)
		)
		
		// clipboard support
		.define_method("clipboard_string=",   &ofAppGLFWWindow::setClipboardString)
		.define_method("clipboard_string",    &ofAppGLFWWindow::getClipboardString)
	;
	
	
	Data_Type<ofBaseApp> rb_cApp =
		define_class_under<ofBaseApp>(rb_mRubyOF, "App");
	
	rb_cApp
		// .define_constructor(Constructor<ofBaseApp>())
		// .define_method("initialize", &Window::initialize)
		
		// timing and framerate
		.define_method("ofGetLastFrameTime", &ofGetLastFrameTime)
		.define_method("ofGetFrameRate",     &ofGetFrameRate)
		.define_method("ofSetFrameRate",     &ofSetFrameRate)
		
		
		// exiting the app
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
		// .define_method("inside_p",    ofRectangle_test_p(&ofRectangle::inside))
		.define_method("inside_r",    ofRectangle_test_r(&ofRectangle::inside))
		.define_method("inside_pp",   ofRectangle_test_pp(&ofRectangle::inside))
		
		.define_method("intersects_r",    ofRectangle_test_r(&ofRectangle::intersects))
		.define_method("intersects_pp",   ofRectangle_test_pp(&ofRectangle::intersects))
	;
	// NOTE: ofRectangle has a lot of logic for aligning rectangular shapes. Could be useful.
	
	
	
	
	
	
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

	
	
	
	Rice::Module rb_cUtils = 
		define_module_under(rb_mRubyOF, "Utils");
	
	rb_cUtils
		.define_module_function("ofResetElapsedTimeCounter",
		                        &ofResetElapsedTimeCounter)
		.define_module_function("ofGetElapsedTimeMicros",
			                     &ofGetElapsedTimeMicros)
		.define_module_function("ofGetElapsedTimeMillis",
		                        &ofGetElapsedTimeMillis)
		.define_module_function("ofGetElapsedTimef",
		                        &ofGetElapsedTimef)
		.define_module_function("ofGetFrameNum",
		                        &ofGetFrameNum)
		
		
		.define_module_function("ofExit", &ofExit,
			(
				Arg("status") = 0
			)
		)
	;
}


// VALUE klass = rb_define_class_under(outer, "Window", rb_cObject);
