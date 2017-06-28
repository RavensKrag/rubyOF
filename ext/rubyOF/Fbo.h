#pragma once

#include "rice.h"

#include "ofFbo.h"

Rice::Class Init_oni_fbo(Rice::Module rb_mOni);

void ofFbo_allocate_from_struct(ofFbo& fbo, Rice::Object rb_settings);
