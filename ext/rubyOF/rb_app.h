#pragma once

// basic includes
#include "ofApp.h"
#include "ofxGui.h"
#include "ofTrueTypeFont.h"
#include "ofColor.h"


// rice data types
#include "rice/Data_Type.hpp"
#include "rice/Constructor.hpp"
#include "rice/Class.hpp"
#include "rice/Module.hpp"
#include "rice/Array.hpp"

// #include "rice/Data_Object.hpp"
// #include "rice/ruby_try_catch.hpp"



class OniApp : public ofApp{

	public:
		OniApp(Rice::Object);
		~OniApp();
		
		void setup();
		void update();
		void draw();
		void exit();

		void keyPressed(int key);
		void keyReleased(int key);
		void mouseMoved(int x, int y );
		void mouseDragged(int x, int y, int button);
		void mousePressed(int x, int y, int button);
		void mouseReleased(int x, int y, int button);
		void mouseEntered(int x, int y);
		void mouseExited(int x, int y);
		void mouseScrolled(int x, int y, float scrollX, float scrollY );
		void windowResized(int w, int h);
		void dragEvent(ofDragInfo dragInfo);
		void gotMessage(ofMessage msg);
		
		ofxPanel gui;
		ofParameterGroup gui_sections;
		ofParameterGroup transforms;
		ofParameter<int> s;
		ofParameter<int> x_pos;
		ofParameter<int> y_pos;
		
		ofParameter<int> gui_scale;
		
		ofTrueTypeFont mFont;
		ofTrueTypeFont mFontU;
		ofTrueTypeFont mFont1;
		ofTrueTypeFont mFont2;
		
		ofImage mImage;
	
	private:
		Rice::Object mSelf;
		
};
