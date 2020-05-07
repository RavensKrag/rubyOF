#include "callbacks.h"

#include <iostream>

using namespace Rice;


// define your callbacks here
int cpp_callback(int x) {
	
	return 1;
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
	
	
	
	
	
	
	
	// 
	// standard binding example:
	// 
	
	// Data_Type<ofPoint> rb_cPoint =
	// 	define_class_under<ofPoint>(rb_mRubyOF, "Point");
	
	// rb_cPoint
	// 	.define_constructor(Constructor<ofPoint, float, float, float>())
	// 	.define_method("get_component",   &ofVec3f_get_component)
	// 	.define_method("set_component",   &ofVec3f_set_component)
	// ;
	
	
	// 
	// binding overloaded member function example
	// 
	
	// rb_cFbo
	// 	.define_constructor(Constructor<ofFbo>())
		
	// 	// .define_method("allocate",  ofFbo_allocWRAP(&ofFbo::allocate))
	// 	.define_method("allocate",  &ofFbo_allocate_from_struct)
		
	// 	.define_method("begin",
	// 		static_cast< void (ofFbo::*)
	// 		(ofFboMode mode)
	// 		>(&ofFbo::begin),
	// 		(
	// 			Arg("mode") = OF_FBOMODE_PERSPECTIVE | OF_FBOMODE_MATRIXFLIP
	// 		)
	// 	)
	// ;
	
	
	// 
	// binding overloaded C++ function example
	// 
	
	// // --- Ok, time to bind some useful stuff.
	// Module rb_mGraphics = define_module_under(rb_mRubyOF, "Graphics");
	// // ------------------
	// // global oF functions
	// // ------------------
	
	// typedef void (*wrap_matrix_op)(const glm::mat4 & m);
	
	// rb_mGraphics
	// 	// bitmap string
	// 	.define_method("ofDrawBitmapString",
	// 		static_cast< void (*)
	// 		(const std::string& textString, float x, float y, float z)
	// 		>(&ofDrawBitmapString)
	// 	)
	// ;
	
	
	
	
	Module rb_mOFX = define_module_under(rb_mRubyOF, "OFX");
	
	Data_Type<ofxMidiOut> rb_c_ofxMidiOut =
		define_class_under<ofxMidiOut>(rb_mOFX, "MidiOut");
	
	rb_c_ofxMidiOut
		.define_constructor(Constructor<ofxMidiOut>())
		.define_method("sendNoteOn",   &ofxMidiOut::sendNoteOn)
		.define_method("sendNoteOff",  &ofxMidiOut::sendNoteOff)
		.define_method("listOutPorts", &ofxMidiOut::listOutPorts)
		
		// .define_method("openPort",     &ofxMidiOut::openPort)
		.define_method("openPort_uint",
			static_cast< bool (ofxMidiOut::*)
			(unsigned int portNumber)
			>(&ofxMidiOut::openPort)
		)
		.define_method("openPort_string",
			static_cast< bool (ofxMidiOut::*)
			(std::string deviceName)
			>(&ofxMidiOut::openPort)
		)
	;
	
	// ofxMidiOut midiOut
	
	
	
	
	// glm uses functions not methods
	// https://openframeworks.cc/documentation/glm/
	
	// can get members of vector either as x and y, or with array-style access
	
	Module rb_mGLM    = define_module("GLM");
	
	Data_Type<glm::tvec2<float>> rb_cVec2_float =
		define_class_under<glm::tvec2<float>>(rb_mGLM, "Vec2_float");
	
	rb_cVec2_float
		.define_method("get_component",   &glm_tvec2_float_get_component)
		.define_method("set_component",   &glm_tvec2_float_set_component)
	;
}


float glm_tvec2_float_get_component(glm::tvec2<float>& p, int i){
	return p[i];
}

void  glm_tvec2_float_set_component(glm::tvec2<float>& p, int i, float value){
	p[i] = value;
}

