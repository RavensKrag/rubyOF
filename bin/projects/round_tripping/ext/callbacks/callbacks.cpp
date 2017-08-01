#include "callbacks.h"

#include <iostream>

using namespace Rice;


// define your callbacks here
int cpp_callback(int x) {
	std::cout << "c++ callback args: " << x << std::endl;
	
	// TODO: implement a better example
	// ideally something with bitshifting / bitmasking
	// (maybe finding prime factorization?)
	// (That would be cool, as being able to return an array into Ruby is a cool part of Rice)
	
	return x * 5;
}


// "main" section
extern "C"
void Init_rubyOF_project()
{
	Module rb_mRubyOF    = define_module("RubyOF");
	Module rb_mCallbacks = define_module_under(rb_mRubyOF, "CPP_Callbacks");
	
	rb_mCallbacks
		.define_module_function("test_callback", &cpp_callback)
	;
	
	
	// Module rb_mRubyOF = define_module("RubyOF");
	
	// 	Rice::Module rb_mGraphics     = Init_rubyOF_graphics(rb_mRubyOF);
	// 	Rice::Class  rb_cFbo          = Init_rubyOF_fbo(rb_mRubyOF);
		
	// 		Data_Type<ofVec4f> rb_cVec4f = 
	// 			define_class_under<ofVec4f>(rb_mRubyOF,  "Vec4f");
			
			
	// 		Module rb_mGraphics = define_module_under(rb_mRubyOF, "Graphics");
			
	// 		Data_Type<ofFbo> rb_cFbo = 
	// 			define_class_under<ofFbo>(rb_mRubyOF, "Fbo");
		
	
	// Data_Type<Launcher> rb_cWindow =
	// 	define_class_under<Launcher>(rb_mRubyOF, "Window");
	
	// rb_cWindow
	// 	.define_constructor(Constructor<Launcher, Rice::Object, int, int>())
	// 	// .define_method("initialize", &Launcher::initialize)
	// 	.define_method("show",   &Launcher::show)
	// 	.define_method("ofExit", &ofExit,
	// 		(
	// 			Arg("status") = 0
	// 		)
	// 	)
		
	// 	.define_method("width",       &ofGetWidth)
	// 	.define_method("height",       &ofGetHeight)
		
	// 	// mouse cursor
	// 	.define_method("show_cursor",       &Launcher::showCursor)
	// 	.define_method("hide_cursor",       &Launcher::hideCursor)
	// ;
	
	
	// Rice::Module rb_cUtils = 
	// 	define_module_under(rb_mRubyOF, "Utils");
	
	// rb_cUtils
	// 	.define_module_function("ofGetElapsedTimeMicros",   &ofGetElapsedTimeMicros)
	// 	.define_module_function("ofGetElapsedTimeMillis",   &ofGetElapsedTimeMillis)
	// 	.define_module_function("ofGetElapsedTimef",        &ofGetElapsedTimef)
	// 	.define_module_function("ofGetFrameNum",            &ofGetFrameNum)
	// ;
}
