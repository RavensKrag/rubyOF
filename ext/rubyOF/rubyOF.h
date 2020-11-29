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



bool ofImage_load(ofImage& image, const std::string& filename);
