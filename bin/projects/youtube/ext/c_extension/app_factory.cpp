#include "app_factory.h"
#include "app.h"

ofBaseApp* appFactory_create(Rice::Object self){
	rbApp* app = new rbApp(self);
	
	return app;
}
