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
	Launcher(Rice::Object self, int width, int height);
	virtual ~Launcher(void);
	
	void initialize();
	void show();
	
	
	
	void hideCursor();
	void showCursor();
	
	void setFullscreen(bool fullScreen);
	void toggleFullscreen();

	void setWindowTitle(std::string title);
	void setWindowPosition(glm::vec2 p);
	void setWindowShape(int w, int h);
	
	void setWindowIcon(const std::string path);
	
	glm::vec2 getWindowPosition();
	glm::vec2 getWindowSize();
	glm::vec2 getScreenSize();
	
	
	void setClipboardString(const std::string& text);
	std::string getClipboardString();
	
	
	
	
	// NOTE: can't use the 'of' prefix for this interface, because it confuses the C++ compiler / linker when it tries to resolve the member functions of this class vs the original functions.
	
	
protected:
	ofBaseApp*       mApp    = NULL;
	ofAppGLFWWindow* mWindow = NULL;
	
	// ofBaseApp* mApp = nullptr;
	// std::shared_ptr<ofAppBaseWindow> mWindow = nullptr;
};

