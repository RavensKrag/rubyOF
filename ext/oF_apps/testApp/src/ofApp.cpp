#include "ofApp.h"

//--------------------------------------------------------------
void ofApp::setup(){
	// NOTE: Using full path to font on Ubuntu linux 16.04 works, but using just the name of the font does not work.
	ofTtfSettings settings("/usr/share/fonts/truetype/fonts-japanese-gothic.ttf", 20); // This works fine
	settings.antialiased = true;
	settings.addRanges({
		 ofUnicode::Space,
	    ofUnicode::Latin,
	    ofUnicode::Latin1Supplement,
	    // ofUnicode::LatinExtendedAdditional,
	    ofUnicode::Hiragana,
	    // ofUnicode::Katakana,
	    // ofUnicode::KatakanaPhoneticExtensions,
	});
	mUnicodeFont.load(settings);
}

//--------------------------------------------------------------
void ofApp::update(){

}

//--------------------------------------------------------------
void ofApp::draw(){
	ofPushStyle();
	
	ofColor color = ofColor::fromHex(0xFF0000, 0xFF);
	ofSetColor(color);
	
	mUnicodeFont.drawString("Testing こんにちは", 200,200);
	
	ofPopStyle();
}

//--------------------------------------------------------------
void ofApp::keyPressed(int key){

}

//--------------------------------------------------------------
void ofApp::keyReleased(int key){

}

//--------------------------------------------------------------
void ofApp::mouseMoved(int x, int y ){

}

//--------------------------------------------------------------
void ofApp::mouseDragged(int x, int y, int button){

}

//--------------------------------------------------------------
void ofApp::mousePressed(int x, int y, int button){

}

//--------------------------------------------------------------
void ofApp::mouseReleased(int x, int y, int button){

}

//--------------------------------------------------------------
void ofApp::mouseEntered(int x, int y){

}

//--------------------------------------------------------------
void ofApp::mouseExited(int x, int y){

}

//--------------------------------------------------------------
void ofApp::windowResized(int w, int h){

}

//--------------------------------------------------------------
void ofApp::gotMessage(ofMessage msg){

}

//--------------------------------------------------------------
void ofApp::dragEvent(ofDragInfo dragInfo){ 

}
