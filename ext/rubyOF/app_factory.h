#pragma once

// basic includes
#include "ofMain.h"

// rice data types
#include "rice/Data_Type.hpp"
#include "rice/Constructor.hpp"
#include "rice/Class.hpp"
#include "rice/Module.hpp"

ofBaseApp* appFactory_create(Rice::Object rb_app);
