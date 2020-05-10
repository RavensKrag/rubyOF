#include "callbacks.h"

#include <iostream>

using namespace Rice;


// define your callbacks here
int cpp_callback(int x) {
	
	return 1;
}


void render_material_editor(
	ofMesh & mesh, ofShader & shader, std::string & shader_filepath,
	ofTexture & tex0, ofTexture & tex1,
	int x, int y, int w, int h)
{
	
	
	shader.load(shader_filepath);
	shader.begin();
	
	shader.setUniformTexture("tex0", tex0, 0);
	shader.setUniformTexture("tex1", tex1, 1);
	
	
	ofPushMatrix();
		ofTranslate(x,y);
      ofScale(w,h);
		
		mesh.draw();
		
	ofPopMatrix();
	
	
	shader.end();
	
}



void init_char_display_bg_mesh(ofMesh & _displayBG, int mesh_w, int mesh_h){
	// create uniform mesh based on dimensions specified by Ruby code
	
	_displayBG.setMode( OF_PRIMITIVE_TRIANGLES );
	for(int j=0; j < mesh_h; j++){
		for(int i=0; i < mesh_w; i++){
		
			_displayBG.addVertex(glm::vec3((i+0), (j+0), 0));
			_displayBG.addColor(ofFloatColor(1,((float) i)/mesh_w,0));
			
			_displayBG.addVertex(glm::vec3((i+1), (j+0), 0));
			_displayBG.addColor(ofFloatColor(1,((float) i)/mesh_w,0));
			
			_displayBG.addVertex(glm::vec3((i+0), (j+1), 0));
			_displayBG.addColor(ofFloatColor(1,((float) i)/mesh_w,0));
			
			_displayBG.addVertex(glm::vec3((i+1), (j+1), 0));
			_displayBG.addColor(ofFloatColor(1,((float) i)/mesh_w,0));
			
		}
	}
	
	for(int i=0; i < mesh_w*mesh_h; i++){
		_displayBG.addIndex(2+i*4);
		_displayBG.addIndex(1+i*4);
		_displayBG.addIndex(0+i*4);
		
		_displayBG.addIndex(2+i*4);
		_displayBG.addIndex(3+i*4);
		_displayBG.addIndex(1+i*4);
	}
	
	
	// apparently, ofColor will auto convert to ofFloatColor as necessary
	// https://forum.openframeworks.cc/t/relation-between-mesh-addvertex-and-addcolor/31314/3
	
	
	// need to replicate the verticies, because each vertex can only take one color
	
}

void set_char_display_bg_color(ofMesh & _displayBG, int i, ofColor & c) {
	
	_displayBG.setColor(0+i*4, c);
	_displayBG.setColor(1+i*4, c);
	_displayBG.setColor(2+i*4, c);
	_displayBG.setColor(3+i*4, c);
	
	
	// TODO: consider using getColorsPointer() to set mulitple colors at once
	// https://openframeworks.cc/documentation/3d/ofMesh/#show_getColorsPointer
	
}

void colorize_char_display_mesh(ofMesh & textMesh, int i, ofColor & c){
	
	textMesh.setColor(0+i*4, c);
	textMesh.setColor(1+i*4, c);
	textMesh.setColor(2+i*4, c);
	textMesh.setColor(3+i*4, c);
	// ^ can't write to this mesh b/c the reference I recieve from ofTrueTypeFont::getStringMesh() is const.
	
}

bool load_char_display_shaders(ofShader & shader, Rice::Array args){
	if(args.size() == 1){
      Rice::Object x = args[0];
      std::string path = from_ruby<std::string>(x);
      return shader.load(path);
   }else if(args.size() == 2 || args.size() == 3){
      return false;
   }
   
   return false;
}



// "main" section
extern "C"
void Init_rubyOF_project()
{
	Module rb_mRubyOF    = define_module("RubyOF");
	Module rb_mCallbacks = define_module_under(rb_mRubyOF, "CPP_Callbacks");
	
	rb_mCallbacks
		.define_module_function("test_callback", &cpp_callback)
		
		
		
		.define_module_function("init_char_display_bg_mesh", 
			                     &init_char_display_bg_mesh)
		
		.define_module_function("set_char_display_bg_color", 
			                     &set_char_display_bg_color)
		
		.define_module_function("colorize_char_display_mesh", 
			                     &colorize_char_display_mesh)
		
		.define_module_function("load_char_display_shaders", 
			                     &load_char_display_shaders)
		
		
		.define_module_function("render_material_editor", 
			                     &render_material_editor)
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
