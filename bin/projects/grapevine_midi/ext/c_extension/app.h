#pragma once

// basic includes
#include "ofMain.h"

// openFrameworks addons
#include "ofxGui.h"
#include "ofxDatGui.h"
#include "ofxImGui.h"
// #include "ofxColorPicker.h"
#include "ofxMidi.h"

// rice data types
#include "rice/Data_Type.hpp"
#include "rice/Constructor.hpp"
#include "rice/Class.hpp"
#include "rice/Module.hpp"
#include "rice/Array.hpp"

// #include "rice/Data_Object.hpp"
// #include "rice/ruby_try_catch.hpp"


class rbApp : public ofBaseApp, public ofxMidiListener {

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
	
		void newMidiMessage(ofxMidiMessage& msg);
		
	protected:
		Rice::Object mSelf;
		
		ofxPanel gui;
		ofxColorPicker_<unsigned char> mColorPicker_Widget;
		ofParameter<ofColor_<unsigned char>> mColorPicker_Parameter;
		ofColor_<unsigned char> mColorPicker_Color;
		// ofColor == ofColor_<unsigned char>
		// need to specify size of color channels for ofxColorPicker
		// and thus for 'consistency' all sizes were specified.
		// However, I don't think non-standard sizes can be used
		// because Rice binds ofColor and not the arbitrary size type.
		
		ofxDatGui* mDatGui;
		
		ofxDatGuiValuePlotter* mPlotter;
		ofxDatGuiLabel*         mLabel1;
		ofxDatGuiLabel*         mLabel2;
		
		
		ofxImGui::Gui im_gui;
		bool mUI_InputCapture;
		
		uint64_t timestamp_us; // timestamp in microseconds (u looks like a greek character)
		
		
		ofxMidiIn midiIn;
		std::vector<ofxMidiMessage> midiMessages;
		std::size_t maxMessages = 10; //< max number of messages to keep track of
		
		ofxMidiOut midiOut;
		
		
		
		ofMesh    _displayBG;
		ofPixels  _displayFG_pixels;
		ofTexture _displayFG_texture;
		
		ofShader _materialEditor_shader;
		ofMesh   _materialEditor_mesh;
};
