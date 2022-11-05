#pragma once

// basic includes
#include "ofMain.h"


// rice data types
#include "rice/Data_Type.hpp"
#include "rice/Constructor.hpp"
#include "rice/Class.hpp"
#include "rice/Module.hpp"



class Launcher
{

public:
	Launcher(Rice::Object rb_app);
	virtual ~Launcher(void);
	
	void show();
	
	// NOTE: can't use the 'of' prefix for this interface, because it confuses the C++ compiler / linker when it tries to resolve the member functions of this class vs the original functions.
	
	
protected:
	ofBaseApp*       mApp    = NULL;
	// ofAppGLFWWindow* mWindow = NULL;
	
	// ofBaseApp* mApp = nullptr;
	std::shared_ptr<ofAppGLFWWindow> mWindow = nullptr;
};

