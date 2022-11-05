// #include "ofMain.h"
// #include "ofGraphics.h"

#include "launcher.h"
#include "app_factory.h"

#include "GLFW/glfw3.h"

#include "rice/Exception.hpp"

#include <iostream>


template<typename T>
struct Null_Free_Function
{
  static void free(T * obj) { }
};


Launcher::Launcher(Rice::Object rb_app){
	cout << "c++: constructor - launcher\n";
	
	// ofAppGlutWindow mWindow;
	// mWindow = new ofAppGlutWindow();
		// Glut window seems to get keyboard input just fine.
		// It seems to break the existing implementation of Ruby-level window closing,
		// but the Ruby-level close callback is still being called, so that's good.
	
	
	// This is the easiest way to prevent a GLFW error:
	// 
	// Simply run the init method once here, and if you get an error code,
	// then there's a problem. This initialization will be performed for real
	// when a new ofAppGLFWWindow is created. We replicate this here only to
	// get an error code, as openFrameworks only prints a human-readable error
	// message. Do this *before* the openFrameworks initialization
	// to make absolutely sure no state will be clobbered.
	bool glfw_error = false;
	if(!glfwInit( )){
		cout << "-- GLFW ERROR DETECTED!!!!\n";
		glfw_error = true;
	}
	
	
	
	
	// // Even if an error has been detected, still proceed with
	// // the full initialization. This way, openFrameworks has
	// // a chance to output it's error message.
	// cout << "-- creating GLFW window\n";
	// mWindow = new ofAppGLFWWindow();
	
	// cout << "-- configuring GLFW window\n";
	// ofSetupOpenGL(mWindow, width,height,OF_WINDOW); // <-------- setup the GL context
	
	
	
	// 
	// load simple config file relative to pwd
	// and use that to set the OpenGL version.
	// 
	// + can't use ofxXmlSettings, because that is an addon
	//   and I can't declare addons for the launcher.
	// 
	// + can't set relative to data directory, because launcher
	//   is shared among many projects and could be compiled separately.
	// 
	
	
	// default to opengl version 3.2
	int opengl_version_major = 3;
	int opengl_version_minor = 2;
	
	// read the config file
	string pwd = ofFilePath::getCurrentWorkingDirectory();
	cout << pwd << endl;
	
	string cfg_path = pwd +"/bin/opengl.cfg";
	
	ofFile file;
	if(ofFile::doesFileExist(cfg_path)){
		cout << "using opengl config: " << cfg_path << endl;
		
		file.open(cfg_path, ofFile::ReadWrite, false);
		ofBuffer buf = file.readToBuffer();
		string text = buf.getText();
		
		cout << "opengl version: " << text << endl;
		
		string delimiter(".");
		
		std::size_t found = text.find(delimiter);
		if(found != std::string::npos){
			opengl_version_major = std::stoi(text.substr(0,found));
			opengl_version_minor = std::stoi(text.substr(found+1));
		}
		
		cout << "major: " << opengl_version_major << endl;
		cout << "minor: " << opengl_version_minor << endl;
	}else{
		opengl_version_major = 3;
		opengl_version_minor = 2;
	}
	
	
	
	// Even if an error has been detected, still proceed with
	// the full initialization. This way, openFrameworks has
	// a chance to output it's error message.
	cout << "-- creating GLFW window\n";
	mWindow = shared_ptr<ofAppGLFWWindow>(new ofAppGLFWWindow());
	
	cout << "-- configuring GLFW window\n";
	// ofSetupOpenGL(mWindow, width,height,OF_WINDOW); // <-------- setup the GL context
		
		// shared_ptr<ofAppGLFWWindow> windowPtr (mWindow);
		
		ofInit();
		auto settings = mWindow->getSettings();
			int width  = from_ruby<int>(rb_app.call("width"));
			int height = from_ruby<int>(rb_app.call("height"));
			
			settings.setSize(width,height);
			settings.windowMode = OF_WINDOW;
			
			settings.setGLVersion(opengl_version_major, opengl_version_minor);
			
			// ^ simply setting the GL version seems to break mouse events? why?
			// After extensive testing, it appears to be an interaction with imgui.
			// I don't understand how that works... but ok.
		ofGetMainLoop()->addWindow(mWindow);
		mWindow->setup(settings);
	
	
	
	
	
	
	// // Even if an error has been detected, still proceed with
	// // the full initialization. This way, openFrameworks has
	// // a chance to output it's error message.
	// cout << "-- creating GLFW window\n";
	// mWindow = new ofAppGLFWWindow();
	
	// cout << "-- configuring GLFW window\n";
	// ofGLFWWindowSettings settings = mWindow->getSettings();
	// 	settings.setGLVersion(3,2);
	// 	settings.setSize(width, height);
	// 	settings.windowMode = OF_WINDOW;
	// ofGetMainLoop()->addWindow(shared_ptr<ofAppGLFWWindow>(mWindow)); // TODO: convert to shared pointer
	// mWindow->setup(settings);
	// // ofSetupOpenGL(mWindow, width,height,OF_WINDOW); // <-------- setup the GL context
	
	
	// ofInit();
	
	
	
	// ofCreateWindow(settings) is define in the file below:
	// ext/openFrameworks/libs/openFrameworks/app/ofAppRunner.cpp
			// ofCreateWindow
				// mainLoop()->createWindow(settings)
	// ext/openFrameworks/libs/openFrameworks/app/ofMainLoop.cpp
	// 
	// 
	// ext/openFrameworks/libs/openFrameworks/app/ofAppGLFWWindow.cpp
	
	
	
	// the correct way to set up a window is using ofCreateWindow()
	// src: https://openframeworks.cc/documentation/application/
	// but currently, that breaks mouse events (not sure why)
	// Maybe this problem will fix itself when I upgrade oF to the stable version? but I really don't know.
	
	// want to eventually transition to using ofCreateWindow, because that will enable multi-window setups, and porting to mobile, etc... but for right now let's not do that.
	
	// cout << "-- creating GLFW window\n";
	// ofGLFWWindowSettings settings;
	// 	settings.setGLVersion(3,2);
	// 	// settings.setSize(width, height);
	// mWindow = ofCreateWindow(settings);
	
	// ofSetWindowShape(width, height);
	
	
	
	// At this point, the error message is out, and the error flag is set.
	// If there is an error, bail out here,
	// to avoid a future Ruby-level segfault.
	if(glfw_error){
		throw Rice::Exception(rb_eRuntimeError, "GLFW initialization error.");
	}
	
	
	
	cout << "-- creating openFrameworks app...\n";
	
		mApp = appFactory_create(rb_app);
		
	cout << "-- app created!\n";
	
	
	cout << "-- binding C++ window and app to RbApp...\n";
	
		Rice::Data_Object<ofAppGLFWWindow> rb_cWindow(
			mWindow.get(),
			Rice::Data_Type< ofAppGLFWWindow >::klass(),
			Rice::Default_Mark_Function< ofAppGLFWWindow >::mark,
			Null_Free_Function< ofAppGLFWWindow >::free
		);
		
		Rice::Data_Object<ofBaseApp> rb_cApp(
			mApp,
			Rice::Data_Type< ofBaseApp >::klass(),
			Rice::Default_Mark_Function< ofBaseApp >::mark,
			Null_Free_Function< ofBaseApp >::free
		);
		
		rb_app.call("bind", rb_cWindow, rb_cApp);
	
	cout << "-- binding complete!\n";
	
	// window is the drawing context
	// app is the thing that holds all the update and render logic
	
	// oF defines different types of windows that can be used, and I want to try the GLFW one
	// (GLFW window appears to be the default, actually)
	
	
	
	// ofAppRunner.cpp   : ofSetupOpenGL
	// ofAppRunner.cpp   : ofCreateWindow
		// ofInit();
		// mainLoop()->createWindow(settings);
	
	// ofMainLoop.cpp:43 : ofMainLoop::createWindow
		// shared_ptr<ofAppGLFWWindow> window =
		// shared_ptr<ofAppGLFWWindow>(new ofAppGLFWWindow());
	// and various other types of windows
	
	
	
	cout << "c++: Launcher::show()\n";
	// this kicks off the running of my app
	// can be OF_WINDOW or OF_FULLSCREEN
	// pass in width and height too:
	ofRunApp(mApp);
}

Launcher::~Launcher(){
	// delete mWindow;
	// ^ Don't need to delete Window any more, because we're using a smart pointer now
	
	// It seems like OpenFrameworks automatically deletes the App.
	// It already needs to intercept the exit callback
	// to make sure that the opengl context is closed appriately,
	// so it also handles freeing the memory for the App.
	// 
	// source: https://github.com/openframeworks/openFrameworks/issues/2603
	// 
	// 
	// As such, attempting to delete it again here results in a segfault.
	// Also, because the destructor for ofBaseApp is virtual,
	// the object will be destroyed as expected.
	// (this is just how C++ polymorphism works)
	// 
	// You can't use a smart pointer to hold mApp for the same reason:
	// when the smart pointer falls out of scope,
	// you trigger a second delete.
	
	
	// delete mApp;
	// appFactory_delete(mApp);
	// mApp = NULL;
	
}


// NOTE: If you explicitly define a method called #initialize, then the C++ constructor wrapper used by Rice will not work correctly. Initialization must happen in the constructor.


void Launcher::show(){
	cout << "c++: Launcher::show()\n";
	// this kicks off the running of my app
	// can be OF_WINDOW or OF_FULLSCREEN
	// pass in width and height too:
	ofRunApp(mApp);
}

// int ofAppGLFWWindow::getCurrentMonitor();


// #ifdef TARGET_LINUX
// 	void setWindowIcon(const string & path);
// 	void setWindowIcon(const ofPixels & iconPixels);
// #endif



// ---------------------------------------------------
