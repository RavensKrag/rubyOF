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


void rubyof_launcher_main(Rice::Object rb_app){
	cout << "-- allocating memory\n";
	
	ofBaseApp*       mApp    = NULL;
	// ofAppGLFWWindow* mWindow = NULL;
	
	// ofBaseApp* mApp = nullptr;
	std::shared_ptr<ofAppGLFWWindow> mWindow = nullptr;
	
	
	cout << "-- initializing GLFW\n";
	
	
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
	
	// ofAppGLFWWindow.cpp : ofAppGLFWWindow::setup(const ofGLFWWindowSettings & _settings)
		// if(!glfwInit( )){
		// 	ofLogError("ofAppGLFWWindow") << "couldn't init GLFW";
		// 	return;
		// }
	
	// Even if an error has been detected, still proceed with
	// the full initialization. This way, openFrameworks has
	// a chance to output it's error message.
	
	
	
	
	
	
	// Documentation says the correct way to create a window is using ofCreateWindow()
	// src: https://openframeworks.cc/documentation/application/
	// Need to use some variant of that code in order to enable multi-window setups,
	// porting to mobile, etc.
		// Some versions of this code break mouse events.
		// Seems ok on v0.11		[ as of 2022.11.05 ]
	
	
	// ofAppRunner.cpp   : ofSetupOpenGL
	// ofAppRunner.cpp   : ofCreateWindow
		// ofInit();
		// mainLoop()->createWindow(settings);
	
	// ofMainLoop.cpp:65-70 : ofMainLoop::createWindow(const ofWindowSettings & settings)
		// [ Preprocessor conditionals omitted for brevity. ]
		// [ They define other types of windows. ]
		// 65     shared_ptr<ofAppGLFWWindow> window = std::make_shared<ofAppGLFWWindow>();
		// ...
		// 68     addWindow(window);
		// 69     window->setup(settings);
		// 70     return window;
	
	// ofMainLoop.h
		// std::shared_ptr<ofAppBaseWindow> createWindow(const ofWindowSettings & settings);
		// template<typename Window>
		// void addWindow(std::shared_ptr<Window> window){
		// 	allowMultiWindow = Window::allowsMultiWindow();
		// 	if(Window::doesLoop()){
		// 	    windowLoop = Window::loop;
		// 	}
		// 	if(Window::needsPolling()){
		// 		windowPollEvents = Window::pollEvents;
		// 	}
		// 	if(!allowMultiWindow){
		// 	    windowsApps.clear();
		// 	}
		// 	windowsApps[window] = std::shared_ptr<ofBaseApp>();
		// 	currentWindow = window;
		// 	ofAddListener(window->events().keyPressed,this,&ofMainLoop::keyPressed);
		// }
	
	
	
	
	
	// window is the drawing context
	// app is the thing that holds all the update and render logic
	
	// oF defines different types of windows that can be used, and I want to try the GLFW one
	// (GLFW window appears to be the default, actually)
	
	
	// ofAppGlutWindow mWindow;
	// mWindow = new ofAppGlutWindow();
		// Glut window seems to get keyboard input just fine.
		// It seems to break the existing implementation of Ruby-level window closing,
		// but the Ruby-level close callback is still being called, so that's good.
	
	cout << "-- creating GLFW window\n";
	mWindow = shared_ptr<ofAppGLFWWindow>(new ofAppGLFWWindow());
	
	cout << "-- configuring GLFW window\n";
	// ofSetupOpenGL(mWindow, width,height,OF_WINDOW); // <-------- setup the GL context
		//                                  ^^^^^^^^^
		// can be OF_WINDOW or OF_FULLSCREEN
	ofInit();
	auto settings = mWindow->getSettings();
		settings.windowMode = OF_WINDOW;
		
		// set window size
		int width  = from_ruby<int>(rb_app.call("width"));
		int height = from_ruby<int>(rb_app.call("height"));
		
		settings.setSize(width,height);
		
		// set opengl version
		// default to opengl version 3.2 (default specified in rb_app.rb)
		int opengl_version_major = from_ruby<int>(rb_app.call("opengl_version_major"));
		int opengl_version_minor = from_ruby<int>(rb_app.call("opengl_version_minor"));
		
		settings.setGLVersion(opengl_version_major, opengl_version_minor);
		
		// ^ simply setting the GL version seems to break mouse events? why?
		// After extensive testing, it appears to be an interaction with imgui.
		// I don't understand how that works... but ok.
	ofGetMainLoop()->addWindow(mWindow);
	mWindow->setup(settings);
	
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
	
	cout << "-- run the ofApp\n";
		// this kicks off the running of my app
		ofRunApp(mApp);
	cout << "-- ofApp has finished\n";
	
	
	cout << "-- clean up memory\n";
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
}

// NOTE: If you explicitly define a method called #initialize, then the C++ constructor wrapper used by Rice will not work correctly. Initialization must happen in the constructor.

// int ofAppGLFWWindow::getCurrentMonitor();


// #ifdef TARGET_LINUX
// 	void setWindowIcon(const string & path);
// 	void setWindowIcon(const ofPixels & iconPixels);
// #endif



// ---------------------------------------------------
