#include "rb_app.h"

OniApp::OniApp(Rice::Object self) : 
	ofApp()
{
	cout << "c++: constructor - window\n";
	
	// ofSetupOpenGL(1024,768,OF_WINDOW); // <-------- setup the GL context
	mSelf = self;
}

OniApp::~OniApp(){
	
}

void OniApp::setup(){
	ofApp::setup();
	
	mSelf.call("setup");
	
	// NOTE: DejaVu Sans just happens to be the defaultu on my system, by whatever mechanism OpenFrameworks decides to use
	// (it's some some sort of FreeDesktop foundation standard API)
	// However, the first call here actually is not actually working right.
	ofTtfSettings settings("DejaVu Sans", 30);
	settings.antialiased = true;
	mFont.load(settings);
	
	ofTtfSettings s1("/usr/share/fonts/truetype/fonts-japanese-gothic.ttf", 20);
	s1.addRanges({
		 ofUnicode::Space,
	    ofUnicode::Latin,
	    ofUnicode::Latin1Supplement,
	    ofUnicode::LatinExtendedAdditional,
	    ofUnicode::Hiragana,
	    ofUnicode::Katakana,
	    ofUnicode::KatakanaPhoneticExtensions,
	});
	s1.antialiased = true;
	mFontU.load(s1);
	
	// NOTE: Liberation serif does not seem to have a "Regular" variant, at least not according to fc-list.
	ofTtfSettings s2("/usr/share/fonts/truetype/liberation/LiberationSerif-Italic.ttf", 20);
	s2.antialiased = true;
	mFont1.load(s2);
	
	ofTtfSettings s3("Liberation Serif", 20);
	s3.antialiased = true;
	mFont2.load(s3);
	
	
	// // ofTtfSettings settings("DejaVu Sans", 20); // tofu: No japanese glyphs
	// ofTtfSettings settings_mUnicodeFont("TakaoPGothic", 20); // This works fine
	// settings_mUnicodeFont.antialiased = true;
	// settings_mUnicodeFont.addRanges({
	//     ofUnicode::Space,
	//     ofUnicode::Latin1Supplement,
	//     ofUnicode::LatinExtendedAdditional,
	//     ofUnicode::Hiragana,
	//     ofUnicode::Katakana,
	//     ofUnicode::KatakanaPhoneticExtensions,
	//     ofUnicode::CJKLettersAndMonths,
	//     ofUnicode::CJKUnified,
	// });
	// mUnicodeFont.load(settings_mUnicodeFont);
	
	
	
	
	// NOTE: These two fonts should display differently
	// If they don't, then it means the font face is not loading properly.
	bool flag;
	
	// ofTtfSettings settings1("DejaVu Sans", 50);
	// settings1.antialiased = true;
	// flag = mFont1.load(settings1);
	// if(flag){
	// 	cout << "font 1 loaded correctly\n";
	// }
	
	// ofTtfSettings settings2("Liberation Serif", 50);
	// settings2.antialiased = true;
	// flag = mFont2.load(settings2);
	// if(flag){
	// 	cout << "font 2 loaded correctly\n";
	// }
	
	
	// The flag is beilg set correctly, but the system is lying.
	// The font face is not, in fact, loading correctly, 
	// as two faces that look quite different (sans serif v. roman)
	// appear exactly the same.
	// 
	// Need to figure out why the font is not being loaded properly.
	// The older version of ofTrueTypeFont I was using did work as I expected,
	// and the current version does not.
	// 
	// Have the assumptions around font load paths changed?
	// Do fonts have to be in the data dir?
	// That used to be the case, but then it changed (maybe it changed back?)
	
	// of particular note:
	// ofTrueTypeFont::load(settings) => loadFontFace() => ofToDataPath()
	// 
	// the inclusion of ofToDataPath() is something that has changed from 
	// the commit on the OpenFrameworks master branch I was previously using.
	// see the diff: https://github.com/openframeworks/openFrameworks/compare/a27821f5287b2430c6368f5a249f...RavensKrag:master
	
	
	// font.load("DejaVu Sans", 20);
	// mFont.loadFont("DejaVu Sans", 20, true, true);
	
	
	
	// font = ofTrueTypeFont();
	
	// =====
	// This is the new proposed ofTrueTypeFont interface,
	// but it is not present in 0.9.8. It is part of a effort
	// to use UTF-8 across the board for OpenFrameworks strings.
	// https://github.com/openframeworks/openFrameworks/pull/3992
	// https://github.com/openframeworks/openFrameworks/blob/3df68ddfeeee8ac1a25de85de9c6a6433f9d3c87/libs/openFrameworks/graphics/ofTrueTypeFont.h
	// (Even though 0.9.8 dropped in December 2016, and this diff is from November, the 0.9.8 release DOES NOT contain this functionality.)
	
	// ofTtfSettings settings("Droid Sans Japanese",24);
	// settings.antialiased = true;
	// settings.ranges = {
	//     ofUnicode::Latin1Supplement,
	//     ofUnicode::Hiragana,
	//     ofUnicode::Katakana,
	//     ofUnicode::CJKUnified
	// };
	
	// font.load(settings);
	
	
	
	
	
	// mImage.load("bin/data/box.jpg");
	
	
	
	// =====
	
	
	// need to call these before gui.setup()
	// ofxGuiSetFont("DejaVu Sans", 20, true, true);
	// ofxGuiSetFont("DejaVu Sans", 200, _bAntiAliased, _bFullCharacterSet, int dpi=0)
	
	ofxGuiSetTextPadding(4);
	ofxGuiSetDefaultWidth(400);
	ofxGuiSetDefaultHeight(40);

	
	
	// transforms.setName("visual transforms");
	// transforms.add(gui_scale.set("GUI scale", 1, 1, 16));
	// transforms.add(s.set("scale", 1, 1, 16));
	// transforms.add(x_pos.set("x", 0, 0, 800));
	// transforms.add(y_pos.set("y", 0, 0, 800));
	
	// gui_sections.add(transforms);
	
	// gui.setup(gui_sections);
}

void OniApp::update(){
	ofApp::update();
	
	mSelf.call("update");
}

void OniApp::draw(){
	ofApp::draw();
	
	
	
	
	ofPushMatrix();
	// ofLoadIdentityMatrix();
	
	
	ofPushStyle();
	
	ofColor color = ofColor::fromHex(0xFF0000, 0xFF);
	ofSetColor(color);
		
		
		int height;
		int x;
		int y;
		ofDrawBitmapString("Font Test", 0, 200, 0);
		
		x = 0;
		y = 300;
		height = mFont.getSize();
		mFont.drawString("mFontU", x, y);
		mFontU.drawString("Hand-woven pagent! こんにちは", x, y+height);
		
		x = 500;
		y = 300;
		height = mFont.getSize();
		mFont.drawString("mFont1", x, y);
		mFont1.drawString("Hand-woven pagent!", x, y+height);
		
		x = 500+300;
		y = 300;
		height = mFont.getSize();
		mFont.drawString("mFont2", x, y);
		mFont2.drawString("Hand-woven pagent!", x, y+height);
		
		
		// mFont.drawString("hello world", 0, 800 + height*1);
		// mUnicodeFont.drawString("こんにちは",	 0, 800 + height*2);
		
		
		// height = mFont1.getLineHeight();
		// mFont1.drawString("Hello World", 200, 200 + height);
		
		// height += mFont2.getLineHeight();
		// mFont2.drawString("Hello World",	 200, 200 + height);
		
		// cout << "こんにちは\n";
		
		
		
		
		// // // Draw some shapes
		// ofDrawRectangle(50, 50, 100, 100); // Top left corner at (50, 50), 100 wide x 100 high
		// ofDrawCircle(250, 100, 50); // Centered at (250, 100), radius of 50
		// ofDrawEllipse(400, 100, 80, 100); // Centered at (400 100), 80 wide x 100 high
		// ofDrawTriangle(500, 150, 550, 50, 600, 150); // Three corners: (500, 150), (550, 50), (600, 150)
		// ofDrawLine(700, 50, 700, 150); // Line from (700, 50) to (700, 150)
		
		
		
		// float height;
		
		// height = 11;
		// 	// ^ src: https://forum.openframeworks.cc/t/how-to-get-size-of-ofdrawbitmapstring/22578
		// ofDrawBitmapString("hello from C++!", 0, 0, 0);
		
		
		// mImage.draw(300,300);
	ofPopStyle();
	ofPopMatrix();
	
	
	
	// gui.draw();
	
	
	
	mSelf.call("draw");
	
	
	
	
}

void OniApp::exit(){
	// ofApp::exit(); // no parent behavior for exit callback defined
	cout << "c++: exit\n";
	
	mSelf.call("on_exit");
}


void OniApp::keyPressed(int key){
	// Something seems to be consuming most keyboard events
	// when the application is started via the Ruby layer in Rake.
	// 
	// That problem prevents this funciton from being called,
	// and also prevents the app from closing when ESC is pressed,
	// like normal ofApp windows do
	// (including the window you get when you execute just the C++ layer of this very project)
	
	ofApp::keyPressed(key);
	
	
	ofLog() << key;
	
	// TODO: consider listening for key symbols (the physical key buttons) as well / instead of this. Need to set up another hook into the oF event system to do that, but might be better / easier for setting up structural keybindings.
	mSelf.call("key_pressed", key);
}

void OniApp::keyReleased(int key){
	ofApp::keyReleased(key);
	
	mSelf.call("key_released", key);
}

void OniApp::mouseMoved(int x, int y ){
	ofApp::mouseMoved(x,y);
	
	mSelf.call("mouse_moved", x,y);
}

void OniApp::mouseDragged(int x, int y, int button){
	ofApp::mouseDragged(x,y,button);
	
	mSelf.call("mouse_dragged", x,y, button);
}

void OniApp::mousePressed(int x, int y, int button){
	ofApp::mousePressed(x,y,button);
	
	mSelf.call("mouse_pressed", x,y, button);
}

void OniApp::mouseReleased(int x, int y, int button){
	ofApp::mouseReleased(x,y,button);
	
	mSelf.call("mouse_released", x,y, button);
}

void OniApp::mouseEntered(int x, int y){
	ofApp::mouseEntered(x,y);
	
	mSelf.call("mouse_entered", x,y);
}

void OniApp::mouseExited(int x, int y){
	ofApp::mouseExited(x,y);
	
	mSelf.call("mouse_exited", x,y);
}

void OniApp::mouseScrolled(int x, int y, float scrollX, float scrollY ){
	ofApp::mouseScrolled(x,y, scrollX, scrollY);
	
	mSelf.call("mouse_scrolled", x,y, scrollX, scrollY);
}

void OniApp::windowResized(int w, int h){
	ofApp::windowResized(w,h);
	
	mSelf.call("window_resized", w,h);
}

void OniApp::dragEvent(ofDragInfo dragInfo){
	// NOTE: drag event example works with Nautilus, but not Thunar (GLFW window)
	
	// https://github.com/openframeworks/openFrameworks/issues/1862
	// ^ this issue explains that Glut windows can not process file drag events on Linux
	
	ofApp::dragEvent(dragInfo);
	
	
	// NOTE: dragInfo.files is a std::vector, not an array. Apparently, Rice doesn't understand how to convert that into a Ruby array? so I guess that needs to be done manually...
	
	// ./test.rb:190:in `show': Unable to convert std::vector<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, std::allocator<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > > >* (ArgumentError)
	
	Rice::Array filepaths;
	
	for(std::__cxx11::basic_string<char>& e : dragInfo.files){
		filepaths.push(to_ruby(e));
	}

	mSelf.call("drag_event", filepaths, dragInfo.position);
}

void OniApp::gotMessage(ofMessage msg){
	ofApp::gotMessage(msg);
	
	// mSelf.call("got_message", msg);
}

