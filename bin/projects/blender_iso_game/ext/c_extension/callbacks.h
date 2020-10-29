#pragma once


#include "ofMain.h"
#include "ofxMidi.h"

#include "ofxGui.h"

// must be AFTER OpenFrameworks includes, or compiler gets confused
// NOTE: Might be able to just run this 'include' from the main CPP file?
//       Not quite sure if I'll ever need the rice types in the header or not.
#include "rice/Data_Type.hpp"
#include "rice/Constructor.hpp"
#include "rice/Class.hpp"
#include "rice/Module.hpp"

#include "rice/Array.hpp"




int ofxMidiMessage__get_status(ofxMidiMessage &self);

int ofxMidiMessage__get_channel(ofxMidiMessage &self);
int ofxMidiMessage__get_pitch(ofxMidiMessage &self);
int ofxMidiMessage__get_velocity(ofxMidiMessage &self);
int ofxMidiMessage__get_value(ofxMidiMessage &self);

double ofxMidiMessage__get_deltatime(ofxMidiMessage &self);

int ofxMidiMessage__get_portNum(ofxMidiMessage &self);
std::string ofxMidiMessage__get_portName(ofxMidiMessage &self);

Rice::Array ofxMidiMessage__get_bytes(ofxMidiMessage &self);


int           ofxMidiMessage__get_num_bytes(ofxMidiMessage &self);
unsigned char ofxMidiMessage__get_byte(ofxMidiMessage &self, int i);

bool ofxMidiMessage__equality(ofxMidiMessage &self, ofxMidiMessage &other);


// NOTE: header will be included in mulitple places, so can't declare the class here, in the kinda sloppy header-only style
class ColorPickerInterface{
public:
	ColorPickerInterface(ofxColorPicker_<unsigned char> *colorPicker);
	
	void setColor(ofColor &color);
	Rice::Data_Object<ofColor> getColorPtr();
	
private:
	ofxColorPicker_<unsigned char>* mColorPicker;
	
	Rice::Data_Object<ofColor>* __rb_color_ptr;

};
