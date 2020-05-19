#include <iostream>
// using namespace std;
using std::cout;
using std::endl;

#include "app.h"

#include "constants/data_path.h"



template<typename T>
struct Null_Free_Function
{
  static void free(T * obj) { }
};


rbApp::rbApp(Rice::Object self)
: ofBaseApp()
{
	cout << "c++: constructor - window\n";
	
	// ofSetupOpenGL(1024,768,OF_WINDOW); // <-------- setup the GL context
	mSelf = self;
}

rbApp::~rbApp(){
	
}

void rbApp::setup(){
	ofSetDataPathRoot(DATA_PATH);
	
	mUI_InputCapture = false;
	
	// ========================================
	// ========== add new stuff here ==========
	mDatGui = new ofxDatGui(0, 50);
	
	// --- Track seconds / frame over time to see performance.
	//     Need a graph, not a single data point, and seconds rather than Hz
	
	// initialize timestamp for time plot
	timestamp_us = 0;
	
	// initialize the time plot itself
	float min = 0;
	float max = 100000;
	mPlotter = mDatGui->addValuePlotter("micros / frame", min, max);
	
	
	// -- add actcual FPS widget
	float framerate_monitor_refresh = 1.0f;
	mDatGui->addFRM(framerate_monitor_refresh);
	
	
	
	
	
	
	
	
	gui.setup("", ofxPanelDefaultFilename, 1500, 0);
	// gui.add(mColorPicker_Widget.setup(mPickedColor, width, height));
	gui.add(mColorPicker_Widget.setup(mColorPicker_Parameter));
	
	// mDatGui->addSlider("ofGui w", 0, 800);
	// mDatGui->addSlider("ofGui h", 0, 800);
	float w = 280;
	float h = 500;
	gui.setSize(w, h);
	gui.setWidthElements(w);
	// gui.setDefaultWidth(float w);
	// gui.setDefaultHeight(float h);
	// https://forum.openframeworks.cc/t/how-to-make-ofxgui-objects-width-smaller/14047
	
	
	
	
	
	
	im_gui.setup();
	ImGui::GetIO().MouseDrawCursor = false;
	
	
	
	
	
	
	// print input ports to console
	midiIn.listInPorts();
	
	// // open port by number (you may need to change this)
	// midiIn.openPort(1);
	// //midiIn.openPort("IAC Pure Data In");	// by name
	// //midiIn.openVirtualPort("ofxMidiIn Input"); // open a virtual port
	midiIn.openPort("Adafruit Trellis M4:Adafruit Trellis M4 MIDI 1 32:0");
	
	// don't ignore sysex, timing, & active sense messages,
	// these are ignored by default
	midiIn.ignoreTypes(false, false, false);
	
	// add ofApp as a listener
	midiIn.addListener(this);
	
	// print received messages to the console
	midiIn.setVerbose(true);
	
	
	
	
	
	// print the available output ports to the console
	midiOut.listOutPorts();
	
	// connect
	// midiOut.openPort(0); // by number
	// //midiOut.openPort("IAC Driver Pure Data In"); // by name
	// //midiOut.openVirtualPort("ofxMidiOut"); // open a virtual port
	midiOut.openPort("Adafruit Trellis M4:Adafruit Trellis M4 MIDI 1 32:0");
	
	
	
	// give ruby access to the midiOut object
	
	Rice::Data_Object<ofxMidiOut> rb_ofxMidiOut_ptr(
		&midiOut,
		Rice::Data_Type< ofxMidiOut >::klass(),
		Rice::Default_Mark_Function< ofxMidiOut >::mark,
		Null_Free_Function< ofxMidiOut >::free
	);
	
	mSelf.call("recieve_cpp_pointer", "midiOut", rb_ofxMidiOut_ptr);
	
	
	
	
	
	
	
	// ========================================
	// ========================================
	
	
	
	// ofParameter::get() returns reference to value,
	// and that is wrapped in a ruby object that acts as a "pointer" to C++ data.
	// Like a pointer, this data only needs to be passed once for changes to propagate.
	Rice::Data_Object<ofColor> rb_color_ptr(
		&const_cast<ofColor_<unsigned char>&>(mColorPicker_Parameter.get()),
		Rice::Data_Type< ofColor >::klass(),
		Rice::Default_Mark_Function< ofColor >::mark,
		Null_Free_Function< ofColor >::free
	);
	// ^ This works, but is not sufficient to draw colored strings fast.
	//   Make sure to also convert string -> mesh if you must draw many strings.
	
	
	// Null_Free_Function< T > is declared at the top of this file.
	// By creating this stubbed callback, the Ruby interpreter has
	// no mechanism to release the memory that has been declared.
	// In this way, memory management can be completely controlled
	// through C++ code (which is what I want for this project).
	
	
	// // NOTE: may not need to use 'to_ruby()' on the Rice::Data_Object
	// mSelf.call("set_gui_parameter", "color", to_ruby(rb_color_ptr));
	
	
	
	// // -- More complex way to pass a pointer from C++ to Ruby
	// //    Allows C++ code to maintain full control of memory management.
	
	// // This is how you can pass a pointer to a C++ type to Ruby-land.
	// // 'Rice::Data_Object' functions basically like a C++ smart pointer,
	// // but allows for data to be sent to Ruby.
	// // NOTE: Like a smart pointer, when this falls out of scope, free() will be called. Thus, make sure the target data is heap allocated.
	
	
	// const void* temp_ptr = mColorPicker_Parameter.getInternalObject();
	// // ^ NOTE: This function is of type 'const void*'
	// //         so you must not write to this data location
	
	// ofColor_<unsigned char> * color_ptr = static_cast<ofColor_<unsigned char> *>(const_cast<void*>(temp_ptr));
	// // strip away the const qualifier
	// // otherwise, can't pass this pointer to Rice::Data_Object< T >()
	
	// Rice::Data_Object<ofColor> rb_color_ptr(
	// 	color_ptr,
	// 	Rice::Data_Type< ofColor >::klass(),
	// 	Rice::Default_Mark_Function< ofColor >::mark,
	// 	Null_Free_Function< ofColor >::free
	// );
	// // NOTE: The rice data type must be ofColor, and not ofColor_<unsigned char>. These two types are equivalent at the level of bits, but only ofColor is wrapped by Rice. As such, Ruby will only understand this specific type, and not the more general form.
	
	// rb_color_ptr.call("freeze");
	// // Freeze rb_color_ptr, so that you can not write to this object at the Ruby level. This preserves the guarantee of 'const' even though 'const' has been stripped away.
	
	// // https://stackoverflow.com/questions/3064509/cast-from-void-to-type-using-c-style-cast-static-cast-or-reinterpret-cast
	
	
	mSelf.call("recieve_cpp_pointer", "colorPicker_color", rb_color_ptr);
	
	
	
	
	
	
	
	
	// material editor needs a single quad as a mesh (two tris)
	_materialEditor_mesh.addVertex(glm::vec3(0,0, 0));
	_materialEditor_mesh.addVertex(glm::vec3(1,0, 0));
	_materialEditor_mesh.addVertex(glm::vec3(0,1, 0));
	_materialEditor_mesh.addVertex(glm::vec3(1,1, 0));
	
	
	_materialEditor_mesh.addIndex(2);
	_materialEditor_mesh.addIndex(1);
	_materialEditor_mesh.addIndex(0);
	
	_materialEditor_mesh.addIndex(2);
	_materialEditor_mesh.addIndex(3);
	_materialEditor_mesh.addIndex(1);
	
	
	
	Rice::Data_Object<ofMesh> rb_c_matEd_mesh(
		&_materialEditor_mesh,
		Rice::Data_Type< ofMesh >::klass(),
		Rice::Default_Mark_Function< ofMesh >::mark,
		Null_Free_Function< ofMesh >::free
	);
	
	mSelf.call("recieve_cpp_pointer", "materialEditor_mesh", rb_c_matEd_mesh);
	
	
	Rice::Data_Object<ofShader> rb_c_matEd_shd(
		&_materialEditor_shader,
		Rice::Data_Type< ofShader >::klass(),
		Rice::Default_Mark_Function< ofShader >::mark,
		Null_Free_Function< ofShader >::free
	);
	
	mSelf.call("recieve_cpp_pointer", "materialEditor_shader", rb_c_matEd_shd);
	
	
	
	
	
	
	
	
	
	// // TODO: should only call ruby-level setup function if C++ level setup finishes successfully. If there is some sort of error at this stage, any ruby-level actions will result in a segfault.
	mSelf.call("setup");
	
	
	// -- More complex way to pass a pointer from C++ to Ruby
	//    Allows C++ code to maintain full control of memory management.
	
	// This is how you can pass a pointer to a C++ type to Ruby-land.
	// 'Rice::Data_Object' functions basically like a C++ smart pointer,
	// but allows for data to be sent to Ruby.
	// NOTE: Like a smart pointer, when this falls out of scope, free() will be called. Thus, make sure the target data is heap allocated.
	
	
	// const void* temp_ptr = mColorPicker_Parameter.getInternalObject();
	// // ^ NOTE: This function is of type 'const void*'
	// //         so you must not write to this data location
	
	// ofColor_<unsigned char> * color_ptr = static_cast<ofColor_<unsigned char> *>(const_cast<void*>(temp_ptr));
	// // strip away the const qualifier
	// // otherwise, can't pass this pointer to Rice::Data_Object< T >()
	
	// Rice::Data_Object<ofColor> rb_color_ptr(
	// 	color_ptr,
	// 	Rice::Data_Type< ofColor >::klass(),
	// 	Rice::Default_Mark_Function< ofColor >::mark,
	// 	Null_Free_Function< ofColor >::free
	// );
	// // NOTE: The rice data type must be ofColor, and not ofColor_<unsigned char>. These two types are equivalent at the level of bits, but only ofColor is wrapped by Rice. As such, Ruby will only understand this specific type, and not the more general form.
	
	// rb_color_ptr.call("freeze");
	// Freeze rb_color_ptr, so that you can not write to this object at the Ruby level. This preserves the guarantee of 'const' even though 'const' has been stripped away.
	
	// https://stackoverflow.com/questions/3064509/cast-from-void-to-type-using-c-style-cast-static-cast-or-reinterpret-cast
	
	
	
}

void rbApp::update(){
	// ========================================
	// ========== add new stuff here ==========
	
	
	// // ofColor picked = mColorPicker_Parameter.get();
	// // mColorPicker_Color.r = picked.r;
	// // mColorPicker_Color.g = picked.g;
	// // mColorPicker_Color.b = picked.b;
	// // mColorPicker_Color.a = picked.a;
	
	
	// // (This one-line style is cleaner, but I'm not sure if it's faster or not. Seems to be a lot of fluxuation in the framerate this way?)
	// mColorPicker_Color = mColorPicker_Parameter.get();
	
	
	// --- Track seconds / frame over time to see performance.
	//     Need a graph, not a single data point, and seconds rather than Hz
	
	// get the current time in microseconds
	// (time the app has been running)
	uint64_t now = ofGetElapsedTimeMicros();
	
	// update the time display based on the current time
	uint64_t microseconds = now - timestamp_us;
	mPlotter->setValue(microseconds);
	
	// save the new time
	timestamp_us = now;
	
	
	
	// float w = mDatGui->getSlider("ofGui w")->getValue();
	// float h = mDatGui->getSlider("ofGui h")->getValue();
	// gui.setSize(w, h);
	// gui.setWidthElements(w);
	
	
	
	
	Rice::Array rb_midiMessageQueue;
	
	for(int i=0; i < midiMessages.size(); i++) {
		ofxMidiMessage &msg = midiMessages[i];
		rb_midiMessageQueue.push(to_ruby(msg));
	}
	
	mSelf.call("recieve_cpp_value", "midiMessageQueue", rb_midiMessageQueue);
	
	
	
	
	
	// ========================================
	// ========================================
	
	mSelf.call("update");
}

void rbApp::draw(){
	// ========================================
	// ========== add new stuff here ==========
	
	
	
	// ========================================
	// ========================================
	
	mSelf.call("draw");
	
	
	gui.draw(); // ofxGui - for color picker
	
	
	
	
	
	
	
	// ========================================
	// ========================================
}

void rbApp::exit(){
	// ofApp::exit(); // no parent behavior for exit callback defined
	cout << "c++: exit\n";
	
	
	// ========================================
	// ========== add new stuff here ==========
	
	delete mDatGui;
	
	
	// clean up
	midiIn.closePort();
	midiIn.removeListener(this);
	
	midiOut.closePort();
	
	
	// ========================================
	// ========================================
	
	
	mSelf.call("on_exit");
}


//--------------------------------------------------------------
void rbApp::newMidiMessage(ofxMidiMessage& msg) {
	
	// add the latest message to the message queue
	midiMessages.push_back(msg);
	
	// remove any old messages if we have too many
	while(midiMessages.size() > maxMessages) {
		midiMessages.erase(midiMessages.begin());
	}
}

//--------------------------------------------------------------
void rbApp::keyPressed(int key){
	// Something seems to be consuming most keyboard events
	// when the application is started via the Ruby layer in Rake.
	// 
	// That problem prevents this funciton from being called,
	// and also prevents the app from closing when ESC is pressed,
	// like normal ofApp windows do
	// (including the window you get when you execute just the C++ layer of this very project)
	
	ofBaseApp::keyPressed(key);
	
	
	ofLog() << key;
	
	
	
	// ========================================
	// ========== add new stuff here ==========
	
	
	
	// ========================================
	// ========================================
	
	
	
	// TODO: consider listening for key symbols (the physical key buttons) as well / instead of this. Need to set up another hook into the oF event system to do that, but might be better / easier for setting up structural keybindings.
	if (!mUI_InputCapture) {
		mSelf.call("key_pressed", key);
	}
}

//--------------------------------------------------------------
void rbApp::keyReleased(int key){
	ofBaseApp::keyReleased(key);
	
	
	
	
	
	
	if (!mUI_InputCapture) {
		mSelf.call("key_released", key);
	}
}

//--------------------------------------------------------------
void rbApp::mouseMoved(int x, int y ){
	ofBaseApp::mouseMoved(x,y);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_moved", x,y);
	}
}

//--------------------------------------------------------------
void rbApp::mouseDragged(int x, int y, int button){
	ofBaseApp::mouseDragged(x,y,button);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_dragged", x,y, button);
	}
}

//--------------------------------------------------------------
void rbApp::mousePressed(int x, int y, int button){
	ofBaseApp::mousePressed(x,y,button);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_pressed", x,y, button);
	}
}

//--------------------------------------------------------------
void rbApp::mouseReleased(int x, int y, int button){
	ofBaseApp::mouseReleased(x,y,button);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_released", x,y, button);
	}
}

//--------------------------------------------------------------
void rbApp::mouseEntered(int x, int y){
	ofBaseApp::mouseEntered(x,y);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_entered", x,y);
	}
}

//--------------------------------------------------------------
void rbApp::mouseExited(int x, int y){
	ofBaseApp::mouseExited(x,y);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_exited", x,y);
	}
}

//--------------------------------------------------------------
void rbApp::mouseScrolled(int x, int y, float scrollX, float scrollY ){
	ofBaseApp::mouseScrolled(x,y, scrollX, scrollY);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_scrolled", x,y, scrollX, scrollY);
	}
}

//--------------------------------------------------------------
void rbApp::windowResized(int w, int h){
	ofBaseApp::windowResized(w,h);
	
	mSelf.call("window_resized", w,h);
}

//--------------------------------------------------------------
void rbApp::dragEvent(ofDragInfo dragInfo){
	// NOTE: drag event example works with Nautilus, but not Thunar (GLFW window)
	
	// https://github.com/openframeworks/openFrameworks/issues/1862
	// ^ this issue explains that Glut windows can not process file drag events on Linux
	// as of 2020.05.07, the issue has been resolved
	// in fact, it was closed on 2017.01.30
	
	ofBaseApp::dragEvent(dragInfo);
	
	
	
	// NOTE: dragInfo.files is a std::vector, not an array. Apparently, Rice doesn't understand how to convert that into a Ruby array? so I guess that needs to be done manually...
	
	// ./test.rb:190:in `show': Unable to convert std::vector<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, std::allocator<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > > >* (ArgumentError)
	
	Rice::Array filepaths;
	
	
	for(int i=0; i < dragInfo.files.size(); i++) {
		std::string &s = dragInfo.files[i];
		filepaths.push(to_ruby(s));
	}
	
	// ofxMidiMessage &message = midiMessages[i];
	
	
	// for(std::string e : dragInfo.files){
	// 	filepaths.push(to_ruby(e));
	// }

	mSelf.call("drag_event", filepaths, dragInfo.position);
}

//--------------------------------------------------------------
void rbApp::gotMessage(ofMessage msg){
	ofBaseApp::gotMessage(msg);
	
	// mSelf.call("got_message", msg);
}

