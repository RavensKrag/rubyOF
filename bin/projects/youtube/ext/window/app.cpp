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
	
	
	// ========================================
	// ========== add new stuff here ==========
	mDatGui = new ofxDatGui(0, 50);
	
	
	
	
	mLabel1   = mDatGui->addLabel("microsecond timer: ");
	mLabel2   = mDatGui->addLabel("microsecond delta: ");
	
	float min = 0;
	float max = 100000;
	mPlotter = mDatGui->addValuePlotter("micros / frame", min, max);
	
	float framerate_monitor_refresh = 1.0f;
	mDatGui->addFRM(framerate_monitor_refresh);
	
	
	// ofxDatGuiValuePlotter* myPlotter = new ofxDatGuiValuePlotter("plot label", min, max);
	
	
	timestamp_us = ofGetElapsedTimeMicros();
	
	
	
	
	
	
	// float width  = 500;
	// float height = 500;
	
	gui.setup();
	// gui.add(mColorPicker_Widget.setup(mPickedColor, width, height));
	gui.add(mColorPicker_Widget.setup(mColorPicker_Parameter));
	
	
	// ========================================
	// ========================================
	
	
	
	
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
	
	
	
	Rice::Data_Object<ofColor> rb_color_ptr(
		&const_cast<ofColor_<unsigned char>&>(mColorPicker_Parameter.get()),
		Rice::Data_Type< ofColor >::klass(),
		Rice::Default_Mark_Function< ofColor >::mark,
		Null_Free_Function< ofColor >::free
	);
	// ^ This works, but render performance is still bad.
	// Is it possible that the ofSetColor function as bound in Ruby is not taking a reference, and is instead allocating new data every frame?
	// Is it immediate mode being slow? May need to convert string to mesh, and then set the color on the mesh? But would need to bind ofMesh before that can be tested.
	
	
	// Null_Free_Function< T > is declared at the top of this file.
	// By creating this stubbed callback, the Ruby interpreter has
	// no mechanism to release the memory that has been declared.
	// In this way, memory management can be completely controlled
	// through C++ code (which is what I want for this project).
	
	
	// NOTE: may not need to use 'to_ruby()' on the Rice::Data_Object
	mSelf.call("font_color=", to_ruby(rb_color_ptr));
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
	
	
	// TODO: need to track ms / frame over time to see which is more performant. Looking at a single number for fps as not a good metric - need a graph.
	
	
	
	// get the current time in microseconds
	// (time the app has been running)
	uint64_t now = ofGetElapsedTimeMicros();
	
	
	// update the time display based on the current time
	uint64_t microseconds = now - timestamp_us;
	
	mLabel1->setLabel("microsecond timer: " + std::to_string(now));
	mLabel2->setLabel("microsecond delta: " + std::to_string(microseconds));
	mPlotter->setValue(microseconds);
	
	
	// save the new time
	timestamp_us = now;
	
	
	
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
	
	
	gui.draw();
}

void rbApp::exit(){
	// ofApp::exit(); // no parent behavior for exit callback defined
	cout << "c++: exit\n";
	
	
	// ========================================
	// ========== add new stuff here ==========
	
	delete mDatGui;
	
	
	// ========================================
	// ========================================
	
	
	mSelf.call("on_exit");
}


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
	mSelf.call("key_pressed", key);
}

void rbApp::keyReleased(int key){
	ofBaseApp::keyReleased(key);
	
	mSelf.call("key_released", key);
}

void rbApp::mouseMoved(int x, int y ){
	ofBaseApp::mouseMoved(x,y);
	
	mSelf.call("mouse_moved", x,y);
}

void rbApp::mouseDragged(int x, int y, int button){
	ofBaseApp::mouseDragged(x,y,button);
	
	mSelf.call("mouse_dragged", x,y, button);
}

void rbApp::mousePressed(int x, int y, int button){
	ofBaseApp::mousePressed(x,y,button);
	
	mSelf.call("mouse_pressed", x,y, button);
}

void rbApp::mouseReleased(int x, int y, int button){
	ofBaseApp::mouseReleased(x,y,button);
	
	mSelf.call("mouse_released", x,y, button);
}

void rbApp::mouseEntered(int x, int y){
	ofBaseApp::mouseEntered(x,y);
	
	mSelf.call("mouse_entered", x,y);
}

void rbApp::mouseExited(int x, int y){
	ofBaseApp::mouseExited(x,y);
	
	mSelf.call("mouse_exited", x,y);
}

void rbApp::mouseScrolled(int x, int y, float scrollX, float scrollY ){
	ofBaseApp::mouseScrolled(x,y, scrollX, scrollY);
	
	mSelf.call("mouse_scrolled", x,y, scrollX, scrollY);
}

void rbApp::windowResized(int w, int h){
	ofBaseApp::windowResized(w,h);
	
	mSelf.call("window_resized", w,h);
}

void rbApp::dragEvent(ofDragInfo dragInfo){
	// NOTE: drag event example works with Nautilus, but not Thunar (GLFW window)
	
	// https://github.com/openframeworks/openFrameworks/issues/1862
	// ^ this issue explains that Glut windows can not process file drag events on Linux
	
	ofBaseApp::dragEvent(dragInfo);
	
	
	// NOTE: dragInfo.files is a std::vector, not an array. Apparently, Rice doesn't understand how to convert that into a Ruby array? so I guess that needs to be done manually...
	
	// ./test.rb:190:in `show': Unable to convert std::vector<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, std::allocator<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > > >* (ArgumentError)
	
	Rice::Array filepaths;
	
	for(std::__cxx11::basic_string<char>& e : dragInfo.files){
		filepaths.push(to_ruby(e));
	}

	mSelf.call("drag_event", filepaths, dragInfo.position);
}

void rbApp::gotMessage(ofMessage msg){
	ofBaseApp::gotMessage(msg);
	
	// mSelf.call("got_message", msg);
}

