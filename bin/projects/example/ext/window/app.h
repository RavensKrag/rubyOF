#pragma once

// basic includes
#include "ofMain.h"

// openFrameworks addons
#include "ofxGui.h"

// rice data types
#include "rice/Data_Type.hpp"
#include "rice/Constructor.hpp"
#include "rice/Class.hpp"
#include "rice/Module.hpp"
#include "rice/Array.hpp"

// #include "rice/Data_Object.hpp"
// #include "rice/ruby_try_catch.hpp"


class rbApp : public ofBaseApp{

	public:
		rbApp(Rice::Object);
		~rbApp();
		
		virtual void setup();
		virtual void update();
		virtual void draw();
		virtual void exit();

		virtual void keyPressed(int key);
		virtual void keyReleased(int key);
		virtual void mouseMoved(int x, int y );
		virtual void mouseDragged(int x, int y, int button);
		virtual void mousePressed(int x, int y, int button);
		virtual void mouseReleased(int x, int y, int button);
		virtual void mouseEntered(int x, int y);
		virtual void mouseExited(int x, int y);
		virtual void mouseScrolled(int x, int y, float scrollX, float scrollY );
		virtual void windowResized(int w, int h);
		virtual void dragEvent(ofDragInfo dragInfo);
		virtual void gotMessage(ofMessage msg);
	
	protected:
		Rice::Object mSelf;
	
	private:
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
};
