#include "callbacks.h"

#include <iostream>

using namespace Rice;


template<typename T>
struct Null_Free_Function
{
  static void free(T * obj) { }
};


// define your callbacks here
int cpp_callback(int x) {
	
	return 1;
}


void render_material_editor(
	ofMesh & mesh, ofShader & shader, std::string & shader_filepath,
	ofTexture & tex0, ofTexture & tex1,
	int x, int y, int w, int h)
{
	stringstream textOut1, textOut2;
	
	textOut1 << "tex0 size: " << tex0.getWidth() << " x " << tex0.getHeight();
	textOut2 << "tex1 size: " << tex1.getWidth() << " x " << tex1.getHeight();
	
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
	
	
	ofPushStyle();
	
	ofColor text_color(0.0);
	
	ofSetColor(text_color);
	
	int bitmap_lineheight = 10;
	int offset = bitmap_lineheight;
	ofDrawBitmapString(textOut1.str(), x, y+offset+h+bitmap_lineheight*1);
	ofDrawBitmapString(textOut2.str(), x, y+offset+h+bitmap_lineheight*2);
	
	ofPopStyle();
}


// Rice can't convert std::string into std::filesystem::path, but they will convert. Thus, we use this helper function. Can establish automatic conversions in Rice, but only when both types are bound.
// 
// https://github.com/jasonroelofs/rice#implicit-casting-implicit_cast
// 
bool ofShader_loadShaders(ofShader & shader, Rice::Array args){
	if(args.size() == 1){
		Rice::Object x = args[0];
		std::string path = from_ruby<std::string>(x);
		return shader.load(path);
	}else if(args.size() == 2 || args.size() == 3){
		return false; // TODO: implement this form as well
	}
	
	return false;
}

// TODO: eventually want to bind uniforms through the ofShader member function, this is just a hold-over
void ofShader_bindUniforms(ofShader & shader, 
	std::string name1, float p1x, float p1y,
	std::string name2, float p2x, float p2y )
{
	shader.setUniform2f(name1, glm::vec2(p1x, p1y));
	shader.setUniform2f(name2, glm::vec2(p2x, p2y));
}



// "header only" class style, at least for now
class CharMappedDisplay{
private:
	int _numCharsX, _numCharsY;
	bool _fgColorUpdateFlag = true;
	bool _bgColorUpdateFlag = true;
	
	// TODO: initialize some more c++ values here, instead of doing them elsewhere and passing them in via the Ruby layer
	
	ofPixels  _bgColorPixels;
	ofMesh    _bgMesh;        // likely the same across instances
	
	
	ofPixels  _fgColorPixels;
	ofTexture _fgColorTexture;
	ofShader  _fgColorShader; // should be the same across instances
	// NOTE: if you're creating multiple instances of this class, probably only need 1 mesh and 1 shader (singleton?)
	
public:
	// CharMappedDisplay(){
		
	// }
	
	// ~CharMappedDisplay(){
		
	// }
	
	
	
	ofColor getColor_fg(int x, int y){
		return _fgColorPixels.getColor(x,y);
	}
	
	ofColor getColor_bg(int x, int y){
		return _bgColorPixels.getColor(x,y);
	}
	
	void setColor_fg(int x, int y, ofColor & c){	
		// set local color cache
		
		
		// (move colors from cache to pixels)
		// set pixel color
		_fgColorPixels.setColor(x,y, c);
		
		if(_fgColorUpdateFlag){
			// move pixel data to texture
			_fgColorTexture.loadData(_fgColorPixels, GL_RGBA);
		}
		// OPTIMIZE: similar to neopixel arduino code, can specify a bunch a pixel changes, and then push them to the GPU all at once
		
	}
	
	void setColor_bg(int x, int y, ofColor & c){
		_bgColorPixels.setColor(x,y, c);
		
		if(_bgColorUpdateFlag){
			// i = pos.x.to_i + pos.y.to_i*(@x_chars) # <-- ruby code
			int i = x + y*_numCharsX;
			// no need to add 1 here, because this only counts visible chars
			// and disregaurds the invisible newline at the end of each line
			
			_bgMesh.setColor(0+i*4, c);
			_bgMesh.setColor(1+i*4, c);
			_bgMesh.setColor(2+i*4, c);
			_bgMesh.setColor(3+i*4, c);
			
			// OPTIMIZE: consider using getColorsPointer() to set mulitple colors at once
			// https://openframeworks.cc/documentation/3d/ofMesh/#show_getColorsPointer
		}
	}
	
	
	int getNumCharsX(){
		return _numCharsX;
	}
	
	int getNumCharsY(){
		return _numCharsY;
	}
	
	
	
	
	
	
	void flushColors_bg(){
		for(int x=0; x < _numCharsX; x++){
			for(int y=0; y < _numCharsY; y++){
				ofColor c(255,0,y*255/_numCharsY, 255);
				int i = x + y*_numCharsX;
				
				_bgMesh.setColor(0+i*4, c);
				_bgMesh.setColor(1+i*4, c);
				_bgMesh.setColor(2+i*4, c);
				_bgMesh.setColor(3+i*4, c);
			}
		}
	}
	
	void flushColors_fg(){
		_fgColorTexture.loadData(_fgColorPixels, GL_RGBA);
	}
	
	
	
	// the "autoUpdate" interface style taken
	// from arduino neopixel library by adafruit
	void autoUpdateColor_fg(bool flag){
		_fgColorUpdateFlag = flag;
	}
	
	void autoUpdateColor_bg(bool flag){
		_bgColorUpdateFlag = flag;
	}
	
	// flush colors to output
	void flush(){
		flushColors_bg();
		flushColors_fg();
	}
	
	
	
	
	
	
	
	Rice::Data_Object<ofShader> fgText_getShader(){
		Rice::Data_Object<ofShader> rb_cPtr(
			&_fgColorShader,
			Rice::Data_Type< ofShader >::klass(),
			Rice::Default_Mark_Function< ofShader >::mark,
			Null_Free_Function< ofShader >::free
		);
		
		return rb_cPtr;
	}
	
	Rice::Data_Object<ofTexture> fgText_getTexture(){
		Rice::Data_Object<ofTexture> rb_cPtr(
			&_fgColorTexture,
			Rice::Data_Type< ofTexture >::klass(),
			Rice::Default_Mark_Function< ofTexture >::mark,
			Null_Free_Function< ofTexture >::free
		);
		
		return rb_cPtr;
	}
	
	
	void bgMesh_draw(){
		_bgMesh.draw();
	}
	
	
	
	
	
	// create uniform mesh based on dimensions specified by Ruby code
	void bgMesh_setup(int w, int h){
		_bgMesh.setMode( OF_PRIMITIVE_TRIANGLES );
		
		for(int j=0; j < h; j++){
			for(int i=0; i < w; i++){
				
				_bgMesh.addVertex(glm::vec3((i+0), (j+0), 0));
				_bgMesh.addColor(ofFloatColor(1,((float) i)/w,0));
				
				_bgMesh.addVertex(glm::vec3((i+1), (j+0), 0));
				_bgMesh.addColor(ofFloatColor(1,((float) i)/w,0));
				
				_bgMesh.addVertex(glm::vec3((i+0), (j+1), 0));
				_bgMesh.addColor(ofFloatColor(1,((float) i)/w,0));
				
				_bgMesh.addVertex(glm::vec3((i+1), (j+1), 0));
				_bgMesh.addColor(ofFloatColor(1,((float) i)/w,0));
				
				// ofColor will auto convert to ofFloatColor as necessary
				// https://forum.openframeworks.cc/t/relation-between-mesh-addvertex-and-addcolor/31314/3
				
				// need to replicate the verticies, because each vertex can only take one color
				
			}
		}
		
		for(int i=0; i < w*h; i++){
			_bgMesh.addIndex(2+i*4);
			_bgMesh.addIndex(1+i*4);
			_bgMesh.addIndex(0+i*4);
			
			_bgMesh.addIndex(2+i*4);
			_bgMesh.addIndex(3+i*4);
			_bgMesh.addIndex(1+i*4);
		}
	}
	
	
	void bgPixels_setup(int w, int h){
		// _fgColorPixels.clear(); // clear frees the color data - not needed
		
		// clear out the garbage
		for(int x=0; x<w; x++){
			for(int y=0; y<h; y++){
				ofColor c(100, 100, 100, 255);
				
				_fgColorPixels.setColor(x,y, c);
			}
		}
	}
	
	
	void fgPixels_setup(int w, int h){
		// _fgColorPixels.clear(); // clear frees the color data - not needed
		
		// clear out the garbage
		for(int x=0; x<w; x++){
			for(int y=0; y<h; y++){
				ofColor c(255, 255, 255, 255);
				
				_fgColorPixels.setColor(x,y, c);
			}
		}
		
		// set specific colors
		for(int i=0; i<30; i++){
			ofColor c;
			c.r = 0;
			c.g = 255;
			c.b = 0;
			c.a = 255;
			
			_fgColorPixels.setColor(i,0, c);
		}
		for(int i=0; i<30; i++){
			ofColor c;
			c.r = 0;
			c.g = 255;
			c.b = 255;
			c.a = 255;
			
			_fgColorPixels.setColor(i,1, c);
		}
		for(int i=0; i<30; i++){
			ofColor c;
			c.r = 0;
			c.g = 0;
			c.b = 255;
			c.a = 255;
			
			_fgColorPixels.setColor(i,2, c);
		}
		
		ofColor white(255, 255, 255,  255 );
		// illuminate 4 px in the top left
		_fgColorPixels.setColor(0,0, white);
		_fgColorPixels.setColor(0,1, white);
		_fgColorPixels.setColor(1,0, white);
		_fgColorPixels.setColor(1,1, white);
		// and light up the other 3 corners with 1 px each
		_fgColorPixels.setColor(0,h-1, white);
		_fgColorPixels.setColor(w-1,0, white);
		_fgColorPixels.setColor(w-1,h-1, white);
	}
	
	void setup( int w, int h ){
		_numCharsX = w;
		_numCharsY = h;
		// int w = 60;
		// int h = 18;
		
		
		_bgColorPixels.allocate(_numCharsX,_numCharsY, OF_PIXELS_RGBA);
		_fgColorPixels.allocate(_numCharsX,_numCharsY, OF_PIXELS_RGBA);
		
		
		bgMesh_setup(_numCharsX,_numCharsY);
		
		bgPixels_setup(_numCharsX,_numCharsY);
		fgPixels_setup(_numCharsX,_numCharsY);
		
		flush();
		
		
		// _fgColorTexture.setTextureWrap(GL_REPEAT, GL_REPEAT);
		_fgColorTexture.setTextureMinMagFilter(GL_NEAREST, GL_NEAREST);
	}
	
	
};




// "main" section
extern "C"
void Init_rubyOF_project()
{
	Module rb_mRubyOF    = define_module("RubyOF");
	Module rb_mCallbacks = define_module_under(rb_mRubyOF, "CPP_Callbacks");
	
	rb_mCallbacks
		.define_module_function("test_callback", &cpp_callback)
		
		
		
		.define_module_function("render_material_editor", 
			                     &render_material_editor)
		
		
		.define_module_function("ofShader_loadShaders", 
			                     &ofShader_loadShaders)
		
		.define_module_function("ofShader_bindUniforms", 
			                     &ofShader_bindUniforms)
	;
	
	
	
	
	
	Module rb_mProject = define_module_under(rb_mRubyOF, "Project");
	
	Data_Type<CharMappedDisplay> rb_c_ofCharMappedDisplay =
		define_class_under<CharMappedDisplay>(rb_mProject, "CharMappedDisplay");
	
	rb_c_ofCharMappedDisplay
		.define_constructor(Constructor<CharMappedDisplay>())
		
		.define_method("bgMesh_setup",   &CharMappedDisplay::bgMesh_setup)
		.define_method("bgPixels_setup", &CharMappedDisplay::bgPixels_setup)
		.define_method("fgPixels_setup", &CharMappedDisplay::fgPixels_setup)
		.define_method("setup",          &CharMappedDisplay::setup)
		
		.define_method("getColor_fg",    &CharMappedDisplay::getColor_fg)
		.define_method("getColor_bg",    &CharMappedDisplay::getColor_bg)
		.define_method("setColor_fg",    &CharMappedDisplay::setColor_fg)
		.define_method("setColor_bg",    &CharMappedDisplay::setColor_bg)
		
		.define_method("getNumCharsX",   &CharMappedDisplay::getNumCharsX)
		.define_method("getNumCharsY",   &CharMappedDisplay::getNumCharsY)
		
		
		.define_method("flushColors_bg", &CharMappedDisplay::flushColors_bg)
		.define_method("flushColors_fg", &CharMappedDisplay::flushColors_fg)
		.define_method("flush",
			&CharMappedDisplay::flush
		)
		.define_method("autoUpdateColor_fg", 
			&CharMappedDisplay::autoUpdateColor_fg
		)
		.define_method("autoUpdateColor_bg", 
			&CharMappedDisplay::autoUpdateColor_bg
		)
		
		.define_method("fgText_getShader",
			&CharMappedDisplay::fgText_getShader
		)
		.define_method("fgText_getTexture",
			&CharMappedDisplay::fgText_getTexture
		)
		
		.define_method("bgMesh_draw",
			&CharMappedDisplay::bgMesh_draw
		)
	;
	
	
	
	
	
	
	
	
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
