#include <iostream>
// using namespace std;
using std::cout;
using std::endl;

#include "app.h"

#include "constants/data_path.h"

#include "Null_Free_Function.h"

#include "ofxDynamicLight.h"




rbApp::rbApp(Rice::Object self)
: ofBaseApp()
{
	cout << "c++: rbApp constructor\n";
	
	// ofSetupOpenGL(1024,768,OF_WINDOW); // <-------- setup the GL context
	mSelf = self;
}

rbApp::~rbApp(){
	
}

void rbApp::setup(){
	cout << "c++: rbApp::setup\n";
	
	ofSetDataPathRoot(DATA_PATH);
	// ofSetBackgroundAuto(false);  
	
	
	mUI_InputCapture = false;
	
	// ========================================
	// ========== add new stuff here ==========
	// mDatGui = new ofxDatGui(0, 300);
	
	// --- Track seconds / frame over time to see performance.
	//     Need a graph, not a single data point, and seconds rather than Hz
	
	// initialize timestamp for time plot
	timestamp_us = 0;
	
	
	
	
	gui.setup("", ofxPanelDefaultFilename, 25, 755);
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
	
	
	
	// give ruby access to the midiOut object
	
	
	
	
	
	
	
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
	
	
	
	
	
	mColorPicker_iterface_ptr = new ColorPickerInterface(&mColorPicker_Widget);
	
	Rice::Data_Object<ColorPickerInterface> rb_colorPicker_ptr(
		mColorPicker_iterface_ptr,
		Rice::Data_Type< ColorPickerInterface >::klass(),
		Rice::Default_Mark_Function< ColorPickerInterface >::mark,
		Null_Free_Function< ColorPickerInterface >::free
	);
	
	mSelf.call("recieve_cpp_pointer", "color_picker", rb_colorPicker_ptr);
	
	rb_colorPicker_ptr.call("setup"); // ruby-level setup function
	
	
	
	
	
	
	// // NOTE: can't do this - have not bound the type ofParameter, so trying to pass the pointer like this will fail.
	
	
	// Rice::Data_Object<ColorPickerInterface> rb_c_colorPicker(
	// 	&mColorPicker_Parameter,
	// 	Rice::Data_Type< ColorPickerInterface >::klass(),
	// 	Rice::Default_Mark_Function< ColorPickerInterface >::mark,
	// 	Null_Free_Function< ColorPickerInterface >::free
	// );
	
	// mSelf.call("recieve_cpp_pointer", "colorPicker", rb_c_colorPicker);
	
	
	// // 
	// mColorPicker_Parameter = ofColor(255,0,0);
	// // ^ ofParameter overloads the = operator, so to set values
	// //   just use equals (feels really weird, I would assume
	// //   it should set the outer variable but it doesn't... but ok)
	
	// // Need to wrap that interface in order to set the color from Ruby
	
	// // Q: can I wrap the color picker in such a way that I can get the color? or is it stil better to pass the pointer from the c++ layer the way I currently do it?
	
	// // (pointer to color picker sent below)
	// // TODO: re-order code, and clean up unused commented out stuff
	
	
	
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
	
	mFrameCounter_update = 0;
	mFrameCounter_draw   = 0;
	
	
	uint64_t dt, timer_start, timer_end;
	timer_start = ofGetElapsedTimeMicros();
	
	
	
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
	// ^ TODO: Rice::Array is memory that is allocated and managed by the ruby interpreter. perhaps I should have a third collection for such data? I'm thinking that cpp_value data means that it was c++ allocated but ruby managed. (which, again, does not describe this particular data, as Rice::Array is essentially a smart pointer that wraps a ruby Array)
	
	
	
	
	// ========================================
	// ========================================
	
	mSelf.call("update");
	
	
	
	
	timer_end = ofGetElapsedTimeMicros();
	dt = timer_end - timer_start;
	
	// mPlotter_update_time->setValue(dt);
	
	mFrameCounter_update = dt;
	
	
	// mDatGui->update();
}

void rbApp::draw(){
	uint64_t dt, timer_start, timer_end;
	timer_start = ofGetElapsedTimeMicros();
	
	// ========================================
	// ========== add new stuff here ==========
	
	// ofSetGlobalAmbientColor(ofFloatColor(1.0, 1.0, 1.0));
	
	// ========================================
	// ========================================
	
	
	// std::cout << "num lights:" << ofxDynamicLightsData().size() << std::endl;
	
	
	// bool cpp_render = true;
	bool cpp_render = false;
		
	if(cpp_render){
		// 
		// FBO render test
		// 
		
		
		ofCamera camera;
		// ofxDynamicMaterial mat1;
		// ofxDynamicMaterial mat2;
		ofMaterial mat1;
		ofMaterial mat2;
		ofMaterial mat_light;
		// ofMesh mesh1;
		// ofMesh mesh2;
		ofLight pointLight;
		
		ofFbo fbo;
		ofFboSettings fbo_settings;
		
		glm::vec3 light_pos(0,0,0);
		
		
		
		
		camera.setPosition(glm::vec3(10,-10,20));
		camera.lookAt(glm::vec3(0,0,0));
		
		ofFloatColor light_color(1, 1, 1);
		pointLight.setDiffuseColor(light_color);
		pointLight.setSpecularColor( ofColor(255.f, 255.f, 255.f));
		pointLight.setPosition(light_pos.x, light_pos.y, light_pos.z);
		
		mat1.setDiffuseColor(ofFloatColor(1,0,0,1));
		mat2.setDiffuseColor(ofFloatColor(0,1,0,1));
		
		mat_light.setEmissiveColor(light_color);
		
		
		
		
		fbo_settings.width = ofGetWidth();
		fbo_settings.height = ofGetHeight();
		fbo_settings.useDepth = true;
		fbo_settings.depthStencilAsTexture = true;
		
		fbo_settings.internalformat = GL_RGBA32F_ARB;
		
		fbo.allocate(fbo_settings);
		
		
		ofSetSphereResolution(32);
		
		ofBackground(255/2, 255/2, 255/2);
		// turn on smooth lighting //
		ofSetSmoothLighting(true);
		
		camera.begin();
			ofEnableDepthTest();
			
			ofEnableLighting();
			
			pointLight.enable();
			
			
			mat_light.begin();
				ofDrawSphere(light_pos, 0.1);
			mat_light.end();
			
			
			
			mat1.begin();
				ofDrawSphere(glm::vec3(0,3,0), 1); // red
			mat1.end();
			
			
			
			ofDisableLighting();
			ofDisableDepthTest();
		
		camera.end();
		
		
		fbo.begin();
		ofBackground(255/6, 255/6, 255/2, 255/5);
		
		camera.begin();
			ofEnableDepthTest();
			
			ofEnableLighting();
			
			pointLight.enable();
			
			
			
			mat2.begin();
				ofDrawSphere(glm::vec3(3,3,0), 1); // green
			mat2.end();
			
			
			
			ofDisableLighting();
			ofDisableDepthTest();
		
		camera.end();
		fbo.end();
		
		fbo.draw(0,0);
		
	}else{
		mSelf.call("draw");
	}
	
	
	
	gui.draw(); // ofxGui - for color picker
	
	
	
	
	
	
	
	// ========================================
	// ========================================
	
	
	
	timer_end = ofGetElapsedTimeMicros();
	dt = timer_end - timer_start;
	
	// mPlotter_draw_time->setValue(dt);
	
	
	mFrameCounter_draw = dt;
	
	// mPlotter_total_time->setValue(mFrameCounter);
	
	
	
	im_gui.begin();
	ImGui::SetWindowFontScale(2.0);
	
	{
		ImGui::Text("Hello, world!");
		
		ImGui::Text("time per phase (ms)");
		
		static bool animate = true;
		ImGui::Checkbox("Animate", &animate);
		
		
		
		const int HIST_SAMPLES = 120;
		
		float hist_min, hist_max;
		hist_min = 0;
		hist_max = 16;
		
		static float v1[HIST_SAMPLES];
		static float v2[HIST_SAMPLES];
		static float v3[HIST_SAMPLES];
		
		if(animate){
			// shift over old data
			for(int i=1; i<HIST_SAMPLES; i++){
				v1[i-1] = v1[i];
				v2[i-1] = v2[i];
			}
			
			// add new data
			v1[HIST_SAMPLES-1] = (float) mFrameCounter_update / 1000;
			v2[HIST_SAMPLES-1] = (float) mFrameCounter_draw / 1000;
			
			// sum update and draw sections
			for(int i=0; i<HIST_SAMPLES; i++){
				v3[i] = v1[i] + v2[i];
			}
		}
		
		
		// void ImGui::PlotHistogram(const char* label, const float* values, int values_count, int values_offset, const char* overlay_text, float scale_min, float scale_max, ImVec2 graph_size, int stride)
		ImGui::PlotHistogram("", v1, HIST_SAMPLES, 0, "update",
			                  hist_min, hist_max, ImVec2(300, 100));
		ImGui::PlotHistogram("", v2, HIST_SAMPLES, 0, "draw",
			                  hist_min, hist_max, ImVec2(300, 100));
		ImGui::PlotHistogram("", v3, HIST_SAMPLES, 0, "total",
			                  hist_min, hist_max, ImVec2(300, 100));
	}
	
	
	im_gui.end();
}

void rbApp::exit(){
	// ofApp::exit(); // no parent behavior for exit callback defined
	cout << "c++: exit\n";
	
	
	// ========================================
	// ========== add new stuff here ==========
	
	delete mColorPicker_iterface_ptr;
	
	// delete mDatGui;
	
	
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


