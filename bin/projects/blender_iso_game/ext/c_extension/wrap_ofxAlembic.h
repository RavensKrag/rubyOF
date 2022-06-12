#pragma once

#include "ofMain.h"
#include "ofxAlembic.h"


// must be AFTER OpenFrameworks includes, or compiler gets confused
// NOTE: Might be able to just run this 'include' from the main CPP file?
//       Not quite sure if I'll ever need the rice types in the header or not.
#include "rice/Data_Type.hpp"
#include "rice/Constructor.hpp"
#include "rice/Class.hpp"
#include "rice/Module.hpp"

#include "rice/Array.hpp"


void wrap_ofxAlembic(Rice::Module rb_mOFX);

Rice::Array ofxAlembic__Reader__getNames(ofxAlembic::Reader& reader);
Rice::Array ofxAlembic__Reader__getFullnames(ofxAlembic::Reader& reader);
Rice::Data_Object<ofxAlembic::IGeom> ofxAlembic__Reader__getNode(ofxAlembic::Reader& reader, const string& path);

std::string ofxAlembic__IGeom__getName(ofxAlembic::IGeom& node);
