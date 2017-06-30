#pragma once


#include "ofMain.h"
// #include "ofApp.h"

	// #include "ofFbo.h"
	// #include "ofPoint.h"
	// #include "ofColor.h"


// must be AFTER OpenFrameworks includes, or compiler gets confused
// NOTE: Might be able to just run this 'include' from the main CPP file?
//       Not quite sure if I'll ever need the rice types in the header or not.
#include "rice.h"



// Behaves as expected. Rice passes the C++ ofPoint correspoinding to 'self' into the function
float ofVec3f_get_component(ofPoint& p, int i);
void  ofVec3f_set_component(ofPoint& p, int i, float value);


int  ofColor_getRed(ofColor& color);
int  ofColor_getGreen(ofColor& color);
int  ofColor_getBlue(ofColor& color);
int  ofColor_getAlpha(ofColor& color);

void ofColor_setRed(ofColor& color, int value);
void ofColor_setGreen(ofColor& color, int value);
void ofColor_setBlue(ofColor& color, int value);
void ofColor_setAlpha(ofColor& color, int value);

