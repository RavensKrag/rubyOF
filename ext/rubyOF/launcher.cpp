// #include "ofMain.h"
// #include "ofGraphics.h"

#include "launcher.h"
#include "app_factory.h"

#include "GLFW/glfw3.h"

#include "rice/Exception.hpp"

#include <iostream>


Launcher::Launcher(Rice::Object self, int width, int height){
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
	
	
	
	
	
	
	
	
	
	// Even if an error has been detected, still proceed with
	// the full initialization. This way, openFrameworks has
	// a chance to output it's error message.
	cout << "-- creating GLFW window\n";
	mWindow = new ofAppGLFWWindow();
	
	cout << "-- configuring GLFW window\n";
	// ofSetupOpenGL(mWindow, width,height,OF_WINDOW); // <-------- setup the GL context
		
		shared_ptr<ofAppGLFWWindow> windowPtr (mWindow);
		
		ofInit();
		auto settings = windowPtr->getSettings();
		settings.setSize(width,height);
		settings.windowMode = OF_WINDOW;
		
		settings.setGLVersion(3,2);
		
		// ^ simply setting the GL version seems to break mouse events? why?
		// After extensive testing, it appears to be an interaction with imgui.
		// I don't understand how that works... but ok.
		
		
		ofGetMainLoop()->addWindow(windowPtr);
		windowPtr->setup(settings);
	
	
	
	
	
	
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
	
	
	
	cout << "-- creating openFrameworks app\n";
	mApp = appFactory_create(self);
	
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


void Launcher::hideCursor(){
	mWindow->hideCursor();
}

void Launcher::showCursor(){
	mWindow->showCursor();
}

void Launcher::setFullscreen(bool fullScreen){
	mWindow->setFullscreen(fullScreen);
}

void Launcher::toggleFullscreen(){
	mWindow->toggleFullscreen();
}

void Launcher::setWindowTitle(std::string title){
	mWindow->setWindowTitle(title);
}

void Launcher::setWindowPosition(int x, int y){
	mWindow->setWindowPosition(x,y);
}

void Launcher::setWindowShape(int w, int h){
	mWindow->setWindowShape(w,h);
}

void Launcher::setWindowIcon(const std::string path){
	// mWindow->setWindowIcon(path); // this method is private. not sure what to do about that.
}


ofPoint Launcher::getWindowPosition(){
	return mWindow->getWindowPosition();
}

ofPoint Launcher::getWindowSize(){
	return mWindow->getWindowSize();
}

ofPoint Launcher::getScreenSize(){
	return mWindow->getScreenSize();
}

void Launcher::setClipboardString(const std::string& text){
	mWindow->setClipboardString(text);
}

std::string Launcher::getClipboardString(){
	return mWindow->getClipboardString();
}

// TODO: bind more methdos.
	// * allow setting of window title

// ofAppGLFWWindow::setWindowTitle(string title)
// ofPoint ofAppGLFWWindow::getWindowPosition();
// ofPoint ofAppGLFWWindow::getScreenSize();
// int ofAppGLFWWindow::getCurrentMonitor();


// #ifdef TARGET_LINUX
// 	void setWindowIcon(const string & path);
// 	void setWindowIcon(const ofPixels & iconPixels);
// #endif



// ---------------------------------------------------
