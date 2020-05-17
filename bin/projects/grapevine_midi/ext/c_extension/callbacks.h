#pragma once


#include "ofMain.h"
#include "ofxMidi.h"

// must be AFTER OpenFrameworks includes, or compiler gets confused
// NOTE: Might be able to just run this 'include' from the main CPP file?
//       Not quite sure if I'll ever need the rice types in the header or not.
#include "rice/Data_Type.hpp"
#include "rice/Constructor.hpp"
#include "rice/Class.hpp"
#include "rice/Module.hpp"

#include "rice/Array.hpp"


float glm_tvec2_float_get_component(glm::tvec2<float>& p, int i);
void  glm_tvec2_float_set_component(glm::tvec2<float>& p, int i, float value);




int ofxMidiMessage__get_status(ofxMidiMessage self);

int ofxMidiMessage__get_channel(ofxMidiMessage self);
int ofxMidiMessage__get_pitch(ofxMidiMessage self);
int ofxMidiMessage__get_velocity(ofxMidiMessage self);
int ofxMidiMessage__get_value(ofxMidiMessage self);

double ofxMidiMessage__get_deltatime(ofxMidiMessage self);

int ofxMidiMessage__get_portNum(ofxMidiMessage self);
std::string ofxMidiMessage__get_portName(ofxMidiMessage self);

Rice::Array ofxMidiMessage__get_bytes(ofxMidiMessage self);


int           ofxMidiMessage__get_num_bytes(ofxMidiMessage self);
unsigned char ofxMidiMessage__get_byte(ofxMidiMessage self, int i);
