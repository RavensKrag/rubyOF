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
	
	
	Data_Type<ofxMidiMessage> rb_c_ofxMidiMessage =
		define_class_under<ofxMidiMessage>(rb_mOFX, "MidiMessage");
	
	rb_c_ofxMidiMessage
		.define_constructor(Constructor<ofxMidiMessage>())
		
		// .define_method("status",    &ofxMidiMessage__get_status)
		
		.define_method("channel",   &ofxMidiMessage__get_channel)
		.define_method("pitch",     &ofxMidiMessage__get_pitch)
		.define_method("velocity",  &ofxMidiMessage__get_velocity)
		.define_method("value",     &ofxMidiMessage__get_value)
		
		.define_method("deltatime", &ofxMidiMessage__get_deltatime)
		
		.define_method("portNum",   &ofxMidiMessage__get_portNum)
		.define_method("portName",  &ofxMidiMessage__get_portName)
		
		
		
		// .define_method("status=",    &ofxMidiMessage__set_status)
		
		.define_method("channel=",   &ofxMidiMessage__set_channel)
		.define_method("pitch=",     &ofxMidiMessage__set_pitch)
		.define_method("velocity=",  &ofxMidiMessage__set_velocity)
		.define_method("value=",     &ofxMidiMessage__set_value)
		
		.define_method("deltatime=", &ofxMidiMessage__set_deltatime)
		
		.define_method("portNum=",   &ofxMidiMessage__set_portNum)
		.define_method("portName=",  &ofxMidiMessage__set_portName)
		
		
		
		.define_method("get_num_bytes",  &ofxMidiMessage__get_num_bytes)
		.define_method("get_byte",       &ofxMidiMessage__get_byte)
	;
	
	
	// TODO: write glue code to access these fields:
	
	
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


// 
// ext/openFrameworks/libs/glm/include/glm/detail/type_vec2.hpp
// 
float glm_tvec2_float_get_component(glm::tvec2<float>& p, int i){
	return p[i];
}

void  glm_tvec2_float_set_component(glm::tvec2<float>& p, int i, float value){
	p[i] = value;
}


// 
// ext/openFrameworks/addons/ofxMidi/src/ofxMidiMessage.h
// 

// unsigned char ofxMidiMessage__get_status(ofxMidiMessage self){
	
// }

int ofxMidiMessage__get_channel(ofxMidiMessage self){
	return self.channel;
}
int ofxMidiMessage__get_pitch(ofxMidiMessage self){
	return self.pitch;
}
int ofxMidiMessage__get_velocity(ofxMidiMessage self){
	return self.velocity;
}
int ofxMidiMessage__get_value(ofxMidiMessage self){
	return self.value;
}

double ofxMidiMessage__get_deltatime(ofxMidiMessage self){
	return self.deltatime;
}

int ofxMidiMessage__get_portNum(ofxMidiMessage self){
	return self.portNum;
}
std::string ofxMidiMessage__get_portName(ofxMidiMessage self){
	return self.portName;
}



// void ofxMidiMessage__set_status(){
	
// }

void ofxMidiMessage__set_channel(ofxMidiMessage self, int ch){
	self.channel = ch;
}
void ofxMidiMessage__set_pitch(ofxMidiMessage self, int pitch){
	self.pitch = pitch;
}
void ofxMidiMessage__set_velocity(ofxMidiMessage self, int vel){
	self.velocity = vel;
}
void ofxMidiMessage__set_value(ofxMidiMessage self, int val){
	self.value = val;
}

void ofxMidiMessage__set_deltatime(ofxMidiMessage self, double dt){
	self.deltatime = dt;
}

void ofxMidiMessage__set_portNum(ofxMidiMessage self, int port){
	self.portNum = port;
}
void ofxMidiMessage__set_portName(ofxMidiMessage self, std::string port){
	self.portName = port;
}



int ofxMidiMessage__get_num_bytes(ofxMidiMessage self){
	return self.bytes.size();
}

unsigned char ofxMidiMessage__get_byte(ofxMidiMessage self, int i){
	return self.bytes[i];
}
