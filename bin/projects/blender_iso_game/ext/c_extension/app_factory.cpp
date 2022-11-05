#include "app_factory.h"
#include "app.h"

ofBaseApp* appFactory_create(Rice::Object rb_app){
	// ProjectApp* app = new ProjectApp(rb_app);
	// TODO: perform proper casting here for portability reasons
	
	return static_cast<ofBaseApp*>(new ProjectApp(rb_app));
}
