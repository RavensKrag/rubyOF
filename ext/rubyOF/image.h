#pragma once

#include "ofImage.h"
#include "ofTexture.h"
#include "ofPixels.h"

#include "rice.h"


typedef struct {
	Rice::Class image;
	Rice::Class texture;
	Rice::Class pixels;
} ITP_Tuple;
// NOTE: "ITP" is just short for "image / texture / pixels"

ITP_Tuple Init_rubyOF_image_texture_pixels(Rice::Module rb_mRubyOF);
