#pragma once

#include "rice.h"

#include "ofMain.h"

	// #include "ofFbo.h"
	// #include "ofPoint.h"
	// #include "ofColor.h"



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

