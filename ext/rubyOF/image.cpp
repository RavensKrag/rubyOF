#include "image.h"

using namespace Rice;

ITP_Tuple Init_rubyOF_image_texture_pixels(Rice::Module rb_mRubyOF)
{
	// ofImage
	// ofTexture
	// ofPixels
	
	
	
	
	// TODO: also bind ofImage#save
	Data_Type<ofImage> rb_cImage = 
		define_class_under<ofImage>(rb_mRubyOF, "Image");
	
	typedef void (ofImage::*ofImage_draw)(float x, float y, float z) const;
	
	
	
	rb_cImage
		.define_constructor(Constructor<ofImage>())
		.define_method("load",   &ofImage_load)
		.define_method("draw",   ofImage_draw(&ofImage::draw))
	;
	
	
	
	
	
	
	
	
	Data_Type<ofTexture> rb_cTexture = 
		define_class_under<ofTexture>(rb_mRubyOF, "Texture");
	
	typedef void (ofTexture::*ofTexture_draw_wh)(float x, float y, float z, float w, float h) const;
	typedef void (ofTexture::*ofTexture_draw_pt)(const glm::vec3 & p1, const glm::vec3 & p2, const glm::vec3 & p3, const glm::vec3 & p4) const;
	
	
	
	rb_cTexture
		.define_constructor(Constructor<ofTexture>())
		.define_method("draw_wh",   ofTexture_draw_wh(&ofTexture::draw))
		.define_method("draw_pt",   ofTexture_draw_pt(&ofTexture::draw))
	;
	
	// void draw(float x, float y, float z, float w, float h) const;
	// void draw(const ofPoint & p1, const ofPoint & p2, const ofPoint & p3, const ofPoint & p4) const;
	// void drawSubsection // <-- many different interfaces. unsure which to bind
	
	
	
	
	
	
	
	
	Data_Type<ofPixels> rb_cPixels = 
		define_class_under<ofPixels>(rb_mRubyOF, "Pixels");
	
	
	
	
	
	
	
	
	return ITP_Tuple{ rb_cTexture, rb_cImage, rb_cPixels };
}



bool ofImage_load(ofImage& image, const std::string& filename){
	// bool load(const std::filesystem::path& fileName, const ofImageLoadSettings &settings = ofImageLoadSettings());
		/// looks for image given by fileName, relative to the data folder.
	
	
	// essentially, performing a typecast
	// (technically a "copy constructor")
	// src: https://stackoverflow.com/questions/43114174/convert-a-string-to-std-filesystem-path
	const std::filesystem::path path = filename;
	
	// NOTE: load can take an optional second settings parameter
	return image.load(path);
}

