#include "image.h"

using namespace Rice;



bool
ofImage_load_fromFile
(ofImage& self, const std::string& filename, const ofImageLoadSettings &settings)
{
	// bool load(const std::filesystem::path& fileName, const ofImageLoadSettings &settings = ofImageLoadSettings());
		/// looks for image given by fileName, relative to the data folder.
	
	
	// essentially, performing a typecast
	// std::string => std::filesystem::path
	// 	(technically a "copy constructor")
	// src: https://stackoverflow.com/questions/43114174/convert-a-string-to-std-filesystem-path
	const std::filesystem::path path = filename;
	 
	// NOTE: load can take an optional second settings parameter
	return self.load(path, settings);
}



void 
ofImageLoadSettings_setAccurate
(ofImageLoadSettings& self, bool flag)
{
	self.accurate = flag;
}

void
ofImageLoadSettings_setExifRotate
(ofImageLoadSettings& self, bool flag)
{
	self.exifRotate = flag;
}

void
ofImageLoadSettings_setGrayscale
(ofImageLoadSettings& self, bool flag)
{
	self.grayscale = flag;
}

void
ofImageLoadSettings_setSeparateCMYK
(ofImageLoadSettings& self, bool flag)
{
	self.separateCMYK = flag;
}


bool
ofImageLoadSettings_isAccurate
(ofImageLoadSettings& self)
{
	return self.accurate;
}

bool
ofImageLoadSettings_isExifRotate
(ofImageLoadSettings& self)
{
	return self.exifRotate;
}

bool
ofImageLoadSettings_isGrayscale
(ofImageLoadSettings& self)
{
	return self.grayscale;
}

bool
ofImageLoadSettings_isSeparateCMYK
(ofImageLoadSettings& self)
{
	return self.separateCMYK;
}



ITP_Tuple Init_rubyOF_image_texture_pixels(Rice::Module rb_mRubyOF)
{
	// ofImage
	// ofTexture
	// ofPixels
	
	
	
	
	// image
		// TODO: also bind ofImage#save
		// TODO: bind the other version of ofImage::load that loads in image data from a buffer (don't do that until I actually need it. Not sure how to use that...)
	Data_Type<ofImage> rb_cImage = 
		define_class_under<ofImage>(rb_mRubyOF, "Image");
	
	
	rb_cImage
		.define_constructor(Constructor<ofImage>())
		.define_method("load",   &ofImage_load_fromFile)
		.define_method("draw",
			static_cast< void (ofImage::*)
			(float x, float y, float z) const
			>(&ofImage::draw)
		)
	;
	
	
	// image settings
	Data_Type<ofImageLoadSettings> rb_cImageLoadSettings = 
		define_class_under<ofImageLoadSettings>(rb_mRubyOF, "ImageLoadSettings");
	
	
	rb_cImageLoadSettings
		.define_constructor(Constructor<ofImageLoadSettings>())
		.define_method("accurate=",     &ofImageLoadSettings_setAccurate)
		.define_method("exifRotate=",   &ofImageLoadSettings_setExifRotate)
		.define_method("grayscale=",    &ofImageLoadSettings_setGrayscale)
		.define_method("separateCMYK=", &ofImageLoadSettings_setSeparateCMYK)
		
		.define_method("accurate?",     &ofImageLoadSettings_isAccurate)
		.define_method("exifRotate?",   &ofImageLoadSettings_isExifRotate)
		.define_method("grayscale?",    &ofImageLoadSettings_isGrayscale)
		.define_method("separateCMYK?", &ofImageLoadSettings_isSeparateCMYK)
	;
	
	
	
	
	
	
	
	
	// texture
	Data_Type<ofTexture> rb_cTexture = 
		define_class_under<ofTexture>(rb_mRubyOF, "Texture");
	
	
	rb_cTexture
		.define_constructor(Constructor<ofTexture>())
		.define_method("draw_wh",
			static_cast< void (ofTexture::*)
			(float x, float y, float z, float w, float h) const
			>(&ofTexture::draw)
		)
		.define_method("draw_pt",
			static_cast< void (ofTexture::*)
			(
				const glm::vec3 & p1,
				const glm::vec3 & p2,
				const glm::vec3 & p3,
				const glm::vec3 & p4
			) const
			>(&ofTexture::draw)
		)
	;
	
	// void draw(float x, float y, float z, float w, float h) const;
	// void draw(const ofPoint & p1, const ofPoint & p2, const ofPoint & p3, const ofPoint & p4) const;
	// void drawSubsection // <-- many different interfaces. unsure which to bind
	
	
	
	
	
	
	
	
	// pixels
	Data_Type<ofPixels> rb_cPixels = 
		define_class_under<ofPixels>(rb_mRubyOF, "Pixels");
	
	
	
	
	
	
	
	
	return ITP_Tuple{ rb_cTexture, rb_cImage, rb_cPixels };
}


