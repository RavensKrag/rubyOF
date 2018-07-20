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
	
	
	
	// c++ --> ruby callback --> c++
	ofPoint input(0,0,0);
	std::cout << "c++ data: " << input << std::endl;
	
	Rice::Object out = mSelf.call("callback_to_cpp", to_ruby(input));
	ofPoint ruby_output = from_ruby<ofPoint>(out);
	std::cout << "c++ -> roundtrip from Ruby: " << ruby_output << std::endl;
	
	
	
	// c++ --> ruby callback --> c++
	// (pointer example)
	
	std::cout << "--------------------------" << std::endl;
	std::cout << "c++ : again! pointer test!" << std::endl;
	ofPoint input2(0,0,0);
	std::cout << "c++ data: " << input2 << std::endl;
	
	
	// -- More complex way to pass a pointer from C++ to Ruby
	//    Allows C++ code to maintain full control of memory management.
	
	// This is how you can pass a pointer to a C++ type to Ruby-land.
	// 'Rice::Data_Object' functions basically like a C++ smart pointer,
	// but allows for data to be sent to Ruby.
	// NOTE: Like a smart pointer, when this falls out of scope, free() will be called. Thus, make sure the target data is heap allocated.
	
	Rice::Data_Object<ofPoint> rb_point_ptr(
		&input2,
		Rice::Data_Type< ofPoint >::klass(),
		Rice::Default_Mark_Function< ofPoint >::mark,
		Null_Free_Function< ofPoint >::free
	);
	
	// Null_Free_Function< T > is declared at the top of this file.
	// By creating this stubbed callback, the Ruby interpreter has
	// no mechanism to release the memory that has been declared.
	// In this way, memory management can be completely controlled
	// through C++ code (which is what I want for this project).
	
	
	Rice::Object out2 = mSelf.call("pointer_callback1", to_ruby(rb_point_ptr));
	ofPoint return_value = from_ruby<ofPoint>(out2);
	std::cout << "c++ -> roundtrip from Ruby: " << return_value << std::endl;
	
	Rice::Object out3 = mSelf.call("pointer_callback2");
	
	std::cout << "c++ -> original Point again: " << input2 << std::endl;
	std::cout << "point fram callback1: " << return_value << std::endl;
	std::cout << "--------------------------" << std::endl;
	
	// NOTE: If you just send a normal C++ object, it will pass by value, not by reference. As such, the data will not be shared between C++ and Ruby. You must use the pointer-wrapping style in order to pass by reference.
	
	// NOTE: Notice how 'input2' changes its value after pointer_callback2(), even though no data was passed to that Ruby method! This is because a pointer was sent to Ruby in pointer_callback1(), which is retained on the Ruby side.
	
	// NOTE: Notice that the data returned in 'return_value' stays the same value, even after pointer_callback2(). This is because 'return_value' is returned by value. Even though a pointer was sent to Ruby, Ruby sent a value back.
	
	
	
	// ========================================
	// ========================================
	
	
	
	// ruby --> c++ callback --> ruby
	// (when the ruby-level call to #setup fires, this pathway will start)
	// The actual c++ callbacks are defined in
	// ext/callbacks/callbacks.cpp
	
	mSelf.call("setup");
}

void rbApp::update(){
	// ========================================
	// ========== add new stuff here ==========
	
	
	
	
	
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

