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


bool
ofImage_load_fromFile
(ofImage& self, const std::string& filename, const ofImageLoadSettings &settings)
;


void 
ofImageLoadSettings_setAccurate
(ofImageLoadSettings& self, bool flag)
;
void
ofImageLoadSettings_setExifRotate
(ofImageLoadSettings& self, bool flag)
;
void
ofImageLoadSettings_setGrayscale
(ofImageLoadSettings& self, bool flag)
;
void
ofImageLoadSettings_setSeparateCMYK
(ofImageLoadSettings& self, bool flag)
;

bool
ofImageLoadSettings_isAccurate
(ofImageLoadSettings& self)
;
bool
ofImageLoadSettings_isExifRotate
(ofImageLoadSettings& self)
;
bool
ofImageLoadSettings_isGrayscale
(ofImageLoadSettings& self)
;
bool
ofImageLoadSettings_isSeparateCMYK
(ofImageLoadSettings& self)
;
