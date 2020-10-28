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
	
	
	// NOTE: may not need to use 'to_ruby()' on the Rice::Data_Object
	mSelf.call("set_gui_parameter", "color", to_ruby(rb_color_ptr));
	
	
	
	
	
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
	
	// ofxDatGui is drawn automatically
	
	
	// ========================================
	// ==========  UI from ofxImGUI  ==========
	
	// im_gui.begin();
	// 	const auto disabled_color = ImVec4(0.60f, 0.60f, 0.60f, 1.00f);
	// 		// Colors[ImGuiCol_TextDisabled] = ImVec4(0.60f, 0.60f, 0.60f, 1.00f);
	// 		// ImGui::TextDisabled("%04d: scrollable region", i);
		
	// 	ImFontAtlas* atlas = ImGui::GetIO().Fonts;
	// 	auto* font = atlas->Fonts[0];
		
	// 	font->Scale = 2.0f;
		
		
	// 	if (ImGui::IsMouseHoveringAnyWindow()){
	// 		// ImGui::SetTooltip("hovering over UI");
	// 		mUI_InputCapture = true;
	// 	}
	// 	else{
	// 		mUI_InputCapture = false;
	// 	}
	// 	ImGui::CaptureKeyboardFromApp(mUI_InputCapture);
	// 	ImGui::CaptureMouseFromApp(mUI_InputCapture);
		
	// 	// if (ImGui::IsItemHovered())
 //      //       ImGui::SetTooltip("hovering over UI");
		
	// 	// ImGui::SliderFloat("Float", &floatValue, 0.0f, 1.0f);
		
	// 	// static bool selected[4] = { false, true, false, false };
	// 	// ImGui::Selectable("1. I am selectable", &selected[0]);
	// 	// ImGui::Selectable("2. I am selectable", &selected[1]);
	// 	// ImGui::Text("3. I am not selectable");
	// 	// ImGui::Selectable("4. I am selectable", &selected[2]);
	// 	// if (ImGui::Selectable("5. I am double clickable", selected[3], ImGuiSelectableFlags_AllowDoubleClick))
	// 	// 	if (ImGui::IsMouseDoubleClicked(0))
	// 	// 		selected[3] = !selected[3];
		
		
		
	// 	ImGui::Text("History");
	// 	Rice::Object history = mSelf.call("history");
		
	// 	static int line = -1; // invalid position, used as init flag
	// 	bool goto_line = ImGui::Button("Goto");
	// 	ImGui::SameLine();
	// 	ImGui::PushItemWidth(100);
	// 	goto_line |= ImGui::InputInt("##Line", &line, 0, 0, ImGuiInputTextFlags_EnterReturnsTrue);
	// 	ImGui::PopItemWidth();
	// 	// ImGui::BeginChild("Sub1", ImVec2(ImGui::GetWindowContentRegionWidth() * 0.5f,300), false, ImGuiWindowFlags_HorizontalScrollbar);
		
		
		
	// 	ImGui::PushStyleVar(ImGuiStyleVar_ChildWindowRounding, 5.0f);
	// 	ImGui::BeginChild("History Buttons", ImVec2(100,300), true);
	// 		if (ImGui::Button("undo"))
	// 		{
	// 			// @history.undo
	// 			auto rb_i = history.call("undo");
	// 			goto_line = true;
	// 			line = from_ruby<int>(rb_i);
	// 		}
			
	// 		if (ImGui::Button("redo"))
	// 		{
	// 			// @history.redo
	// 			auto rb_i = history.call("redo");
	// 			goto_line = true;
	// 			line = from_ruby<int>(rb_i);
	// 		}
			
	// 		if (ImGui::Button("squash"))
	// 		{
	// 			// @history.squash
	// 			auto rb_i = history.call("squash");
	// 			goto_line = true;
	// 			line = from_ruby<int>(rb_i);
	// 		}
	// 	ImGui::EndChild();
	// 	ImGui::PopStyleVar();
		
		
	// 	ImGui::SameLine();
		
		
	// 	ImGui::BeginChild("History", ImVec2(0,0), false, ImGuiWindowFlags_HorizontalScrollbar);
		
	// 	// int length = history.call("length");
	// 	// cout << "c++: " << history[1] << "\n";
		
	// 	// auto x = mSelf.call("history").call("messages").call("size");
	// 	// cout << "c++: " << x << "\n";
		
	// 	// display history list
	// 	Rice::Array history_list = history.call("messages");
	// 	int length = from_ruby<int>(history_list.call("length"));
	// 	int pos    = from_ruby<int>(history.call("position"));
	// 	// ^ must do explict cast using from_ruby< T >()
	// 	// cout << "c++: " << "(" << length << ", " << pos << ")" << "\n";
		
	// 	// Rice::String 
	// 	Rice::Array::iterator itr = history_list.begin();
	// 	Rice::Array::iterator end = history_list.end();
	// 	for(; itr != end; ++itr) // NOTE: must be ++itr, not itr++
	// 	{
	// 		// std::string button_label = "%04d: scrollable region";
	// 		// const char *cstr = button_label.c_str();
	// 		// // ^ in a similar style, you can call c_str() on the Rice::String to get the underlying c array.
			
	// 		// rb_str = history_list[i];
	// 		Rice::Object element = *itr;
	// 		Rice::String rb_str = element;
	// 		const char* cstr = rb_str.c_str();
			
	// 		int i = itr.index();
	// 		if (i <= pos){
	// 			// ImGui::PushItemWidth(-1);
	// 			ImGui::Button(cstr, ImVec2(-1,0));
	// 			// ImGui::PopItemWidth();
	// 		}else{
	// 			// auto color = ImColor::HSV(i/7.0f, 0.6f, 0.6f);
				
	// 			// ImGui::PushStyleColor(ImGuiCol_Button, color);
	// 			ImGui::PushStyleColor(ImGuiCol_Text, disabled_color);
	// 			// ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImColor::HSV(i/7.0f, 0.7f, 0.7f));
 //            // ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImColor::HSV(i/7.0f, 0.8f, 0.8f));
	// 			ImGui::Button(cstr, ImVec2(-1,0));
	// 			ImGui::PopStyleColor();
				
				
	// 			// ImGui::PushStyleVar(ImGuiStyleVar_ButtonTextAlign, );
	// 			// ImGuiStyle& style = ImGui::GetStyle();
	// 			// style.ButtonTextAlign;
	// 			// ^ Need to upgrade ofxImGui in order to set the button text alignment. That will, in turn, require an upgrade to OpenFrameworks.
				
	// 			// NOTE: to push multiple styles unto the stack for a single object, use ImGui::PushID(int i)
	// 		}
	// 		if (ImGui::IsItemHovered()){
	// 			if (ImGui::IsMouseClicked(1)){
	// 				history.call("goto", i);
	// 				goto_line |= true;
	// 				line = i;
	// 			}
	// 		}
	// 		if (goto_line && line == i){
	// 			cout << "set scroll middle: " << line << endl;
	// 			ImGui::SetScrollHere();
	// 		}
	// 	}
	// 	if (line == -1){
	// 		cout << "hello world! initial line count" << endl;
	// 		cout << "set scroll bottom: " << line << endl;
	// 		// jump to end on initialization
	// 		// int i = from_ruby<int>(history.call("position"));
	// 		// goto_line = true;
	// 		line = length - 1;
	// 		ImGui::SetScrollHere();
	// 	}
	// 	if (goto_line && line > length-1){
	// 		cout << "set scroll overshoot bottom: " << line << endl;
	// 		// without the goto_line check, it constantly scrolls to the endpoint
	// 		// TODO: figure out how to get scrolling section to scroll to bottom on init only, not every frame
	// 		line = length-1;
	// 		ImGui::SetScrollHere();
	// 	}
		
	// 	ImGui::EndChild();
		
	// 	// NOTE: If width is set to 0, will take up the remainder of the space. If the first item in a row takes the full width, there will be no space left over.
	// 	// NOTE: Can use negative width to align to right edge
	// 	//       See "Widgets Width" example for details.
		
	// 	// TODO: fix how UI handles scroll weel events - interfers with zoom
	// 	// NOTE: scrolling on ofxGUI causes scroll input to be handled by the UI widget only. However, scrolling on ofxDatGui or ofxImGui does not have that effect. Thus, scrolling on color picker does not zoom camera, but scrolling on other UI elements does zoom the camera.
		
		
	// 	// Consider the proposed "infinite history" feature. How would such a thing be implemented? What is the size of the scrolling list? Consider comparisons with version control.
	// 		// OpenFrameworks has over 16,000 commits in its git repo.
	// 		// it is possible for gitg to show all of these, though clearly the ones that are not currently on screen are being culled in some way. Is ImGui sophisticated enough to cull like that? Perhaps, but perhaps not. (I assume not.)
		
		
	// im_gui.end();
	
	// ========================================
	// ========================================
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
	if (!mUI_InputCapture) {
		mSelf.call("key_pressed", key);
	}
}

void rbApp::keyReleased(int key){
	ofBaseApp::keyReleased(key);
	
	if (!mUI_InputCapture) {
		mSelf.call("key_released", key);
	}
}

void rbApp::mouseMoved(int x, int y ){
	ofBaseApp::mouseMoved(x,y);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_moved", x,y);
	}
}

void rbApp::mouseDragged(int x, int y, int button){
	ofBaseApp::mouseDragged(x,y,button);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_dragged", x,y, button);
	}
}

void rbApp::mousePressed(int x, int y, int button){
	ofBaseApp::mousePressed(x,y,button);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_pressed", x,y, button);
	}
}

void rbApp::mouseReleased(int x, int y, int button){
	ofBaseApp::mouseReleased(x,y,button);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_released", x,y, button);
	}
}

void rbApp::mouseEntered(int x, int y){
	ofBaseApp::mouseEntered(x,y);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_entered", x,y);
	}
}

void rbApp::mouseExited(int x, int y){
	ofBaseApp::mouseExited(x,y);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_exited", x,y);
	}
}

void rbApp::mouseScrolled(int x, int y, float scrollX, float scrollY ){
	ofBaseApp::mouseScrolled(x,y, scrollX, scrollY);
	
	if (!mUI_InputCapture) {
		mSelf.call("mouse_scrolled", x,y, scrollX, scrollY);
	}
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

