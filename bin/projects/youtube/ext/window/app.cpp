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
	
	Rice::Data_Object<ofColor> rb_color_ptr(
		&mColorPicker_Color,
		Rice::Data_Type< ofColor >::klass(),
		Rice::Default_Mark_Function< ofColor >::mark,
		Null_Free_Function< ofColor >::free
	);
	
	// Null_Free_Function< T > is declared at the top of this file.
	// By creating this stubbed callback, the Ruby interpreter has
	// no mechanism to release the memory that has been declared.
	// In this way, memory management can be completely controlled
	// through C++ code (which is what I want for this project).
	
	
	// NOTE: may not need to use 'to_ruby()' on the Rice::Data_Object
	mSelf.call("font_color=", to_ruby(rb_color_ptr));
	
	// TODO: Need to figure out a way to manage the memory, so Ruby can let go of the pointer, without deleting C++ memory. Can I pass a shared_ptr instead of a raw pointer into Rice::Data_Object?
}

void rbApp::update(){
	// ========================================
	// ========== add new stuff here ==========
	
	
	// (do seem to be taking a performance hit to access the heap-allocated memory, as expected)
	ofColor picked = mColorPicker_Parameter.get();
	mColorPicker_Color.r = picked.r;
	mColorPicker_Color.g = picked.g;
	mColorPicker_Color.b = picked.b;
	mColorPicker_Color.a = picked.a;
	
	
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

