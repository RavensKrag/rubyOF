#include "ofMain.h"
#include "GraphicsAdvanced.h"

// #include "ofImage.h"
// #include "ofTexture.h"
// #include "ofPixels.h"

using namespace Rice;

#include "rice/Array.hpp"


// 
// Image
// 

bool
ofImage_load_fromFile
(ofImage& self, const std::string& filename, const ofImageLoadSettings &settings)
{
   // bool load(const std::filesystem::path& fileName, const ofImageLoadSettings &settings = ofImageLoadSettings());
      /// looks for image given by fileName, relative to the data folder.
   
   
   // essentially, performing a typecast
   // std::string => std::filesystem::path
   //    (technically a "copy constructor")
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



// ----------------------
// from ext/openFrameworks/libs/openFrameworks/graphics/ofImage.cpp

#include "FreeImage.h"

template <typename T>
FREE_IMAGE_TYPE getFreeImageType(const ofPixels_<T>& pix);

template <>
FREE_IMAGE_TYPE getFreeImageType(const ofPixels& pix);

template <>
FREE_IMAGE_TYPE getFreeImageType(const ofShortPixels& pix);
template <>
FREE_IMAGE_TYPE getFreeImageType(const ofFloatPixels& pix);

//----------------------------------------------------
template<typename PixelType>
FIBITMAP* getBmpFromPixels(const ofPixels_<PixelType> &pix){
   const PixelType* pixels = pix.getData();
   unsigned int width = pix.getWidth();
   unsigned int height = pix.getHeight();
   unsigned int bpp = pix.getBitsPerPixel();

   FREE_IMAGE_TYPE freeImageType = getFreeImageType(pix);
   FIBITMAP* bmp = FreeImage_AllocateT(freeImageType, width, height, bpp);
   unsigned char* bmpBits = FreeImage_GetBits(bmp);
   if(bmpBits != nullptr) {
      int srcStride = width * pix.getBytesPerPixel();
      int dstStride = FreeImage_GetPitch(bmp);
      unsigned char* src = (unsigned char*) pixels;
      unsigned char* dst = bmpBits;
      if(srcStride != dstStride){
         for(int i = 0; i < (int)height; i++) {
            memcpy(dst, src, srcStride);
            src += srcStride;
            dst += dstStride;
         }
      }else{
         memcpy(dst,src,dstStride*height);
      }
   } else {
      ofLogError("ofImage") << "getBmpFromPixels(): unable to get FIBITMAP from ofPixels";
   }

   // ofPixels are top left, FIBITMAP is bottom left
   FreeImage_FlipVertical(bmp);

   return bmp;
}

//----------------------------------------------------
template<typename PixelType>
void putBmpIntoPixels(FIBITMAP * bmp, ofPixels_<PixelType>& pix, bool swapOnLittleEndian = true) {

   // convert to correct type depending on type of input bmp and PixelType
   FIBITMAP* bmpConverted = nullptr;
   FREE_IMAGE_TYPE imgType = FreeImage_GetImageType(bmp);
   if(sizeof(PixelType)==1 &&
      (FreeImage_GetColorType(bmp) == FIC_PALETTE || FreeImage_GetBPP(bmp) < 8
      ||  imgType!=FIT_BITMAP)) {
      if(FreeImage_IsTransparent(bmp)) {
         bmpConverted = FreeImage_ConvertTo32Bits(bmp);
      } else {
         bmpConverted = FreeImage_ConvertTo24Bits(bmp);
      }
      bmp = bmpConverted;
   }else if(sizeof(PixelType)==2 && imgType!=FIT_UINT16 && imgType!=FIT_RGB16 && imgType!=FIT_RGBA16){
      if(FreeImage_IsTransparent(bmp)) {
         bmpConverted = FreeImage_ConvertToType(bmp,FIT_RGBA16);
      } else {
         bmpConverted = FreeImage_ConvertToType(bmp,FIT_RGB16);
      }
      bmp = bmpConverted;
   }else if(sizeof(PixelType)==4 && imgType!=FIT_FLOAT && imgType!=FIT_RGBF && imgType!=FIT_RGBAF){
      if(FreeImage_IsTransparent(bmp)) {
         bmpConverted = FreeImage_ConvertToType(bmp,FIT_RGBAF);
      } else {
         bmpConverted = FreeImage_ConvertToType(bmp,FIT_RGBF);
      }
      bmp = bmpConverted;
   }

   unsigned int width = FreeImage_GetWidth(bmp);
   unsigned int height = FreeImage_GetHeight(bmp);
   unsigned int bpp = FreeImage_GetBPP(bmp);
   unsigned int channels = (bpp / sizeof(PixelType)) / 8;
    unsigned int pitch = FreeImage_GetPitch(bmp);
#ifdef TARGET_LITTLE_ENDIAN
   bool swapRG = channels && swapOnLittleEndian && (bpp/channels == 8);
#else
   bool swapRG = false;
#endif


   ofPixelFormat pixFormat;
   if(channels==1) pixFormat=OF_PIXELS_GRAY;
   if(swapRG){
      if(channels==3) pixFormat=OF_PIXELS_BGR;
      if(channels==4) pixFormat=OF_PIXELS_BGRA;
   }else{
      if(channels==3) pixFormat=OF_PIXELS_RGB;
      if(channels==4) pixFormat=OF_PIXELS_RGBA;
   }

   // ofPixels are top left, FIBITMAP is bottom left
   FreeImage_FlipVertical(bmp);

   unsigned char* bmpBits = FreeImage_GetBits(bmp);
   if(bmpBits != nullptr) {
      pix.setFromAlignedPixels((PixelType*) bmpBits, width, height, pixFormat, pitch);
   } else {
      ofLogError("ofImage") << "putBmpIntoPixels(): unable to set ofPixels from FIBITMAP";
   }

   if(bmpConverted != nullptr) {
      FreeImage_Unload(bmpConverted);
   }

   if(swapRG && channels >=3 ) {
      pix.swapRgb();
   }
}

// ofPixels__flip_pixels is based on this extension of ofImage:
// https://github.com/diederickh/ofxImage/blob/master/src/ofxImage.cpp
template<typename PixelType>
void ofPixels__flip_pixels(ofPixels_<PixelType> &pix, const bool horizontal, const bool vertical){
   
   if(!horizontal && !vertical){
      return;
   }
   
   
   // 
   // load into free image format
   // 
   const PixelType* pixels = pix.getData();
   unsigned int width = pix.getWidth();
   unsigned int height = pix.getHeight();
   unsigned int bpp = pix.getBitsPerPixel();

   FREE_IMAGE_TYPE freeImageType = getFreeImageType(pix);
   FIBITMAP* bmp = FreeImage_AllocateT(freeImageType, width, height, bpp);
   unsigned char* bmpBits = FreeImage_GetBits(bmp);
   if(bmpBits != nullptr) {
      int srcStride = width * pix.getBytesPerPixel();
      int dstStride = FreeImage_GetPitch(bmp);
      unsigned char* src = (unsigned char*) pixels;
      unsigned char* dst = bmpBits;
      if(srcStride != dstStride){
         for(int i = 0; i < (int)height; i++) {
            memcpy(dst, src, srcStride);
            src += srcStride;
            dst += dstStride;
         }
      }else{
         memcpy(dst,src,dstStride*height);
      }
   } else {
      ofLogError("ofImage") << "getBmpFromPixels(): unable to get FIBITMAP from ofPixels";
   }

   // ofPixels are top left, FIBITMAP is bottom left
   // FreeImage_FlipVertical(bmp);
   
   
   // 
   // flip the image as necessary
   // 
   
   bool horSuccess = false, vertSuccess = false;
   
   if(vertical){
      // FreeImage_FlipVertical(bmp);
      vertSuccess = FreeImage_FlipVertical(bmp);
   }else{
      // // ofPixels are top left, FIBITMAP is bottom left
      // FreeImage_FlipVertical(bmp);
   }
   
   if(horizontal){
      horSuccess = FreeImage_FlipHorizontal(bmp);
   }
   
   
   // 
   // if transformation was made, convert back to ofPixels format
   // 
   if(horSuccess || vertSuccess){
      // convert to correct type depending on type of input bmp and PixelType
      unsigned int channels = (bpp / sizeof(PixelType)) / 8;
      unsigned int pitch = FreeImage_GetPitch(bmp);
   #ifdef TARGET_LITTLE_ENDIAN
      bool swapRG = channels && (bpp/channels == 8);
   #else
      bool swapRG = false;
   #endif
      
      
      ofPixelFormat pixFormat = pix.getPixelFormat();
      
      
      unsigned char* bmpBits = FreeImage_GetBits(bmp);
      if(bmpBits != nullptr) {
         pix.setFromAlignedPixels((PixelType*) bmpBits, width, height, pixFormat, pitch);
      } else {
         ofLogError("ofImage") << "putBmpIntoPixels(): unable to set ofPixels from FIBITMAP";
      }
      
      if(swapRG && channels >=3 ) {
         pix.swapRgb();
      }
   }
   
   if (bmp != NULL)            FreeImage_Unload(bmp);
   
   return;
}


// 
// Pixels
// Pixels_<unsigned char>
// 

ofColor ofPixels__getColor_xy(ofPixels &pixels, size_t x, size_t y){
   return pixels.getColor(x,y);
}

void ofPixels__setColor_xy(ofPixels &pixels, size_t x, size_t y, const ofColor &color){
   pixels.setColor(x,y,color);
}

void ofPixels__setColor_all(ofPixels &pixels, const ofColor &color){
   pixels.setColor(color);
}

void ofPixels__setColor_i(ofPixels &pixels, size_t i, const ofColor &color){
   pixels.setColor(i,color);
}

void ofPixels_flip(ofPixels &pixels, const bool horizontal, const bool vertical){
   ofPixels__flip_pixels(pixels, horizontal, vertical);
}

// ----------------------

// 
// FloatPixels
// Pixels_<float>
// 

ofFloatColor ofFloatPixels__getColor_xy(ofFloatPixels &pixels, size_t x, size_t y){
   return pixels.getColor(x,y);
}

void ofFloatPixels__setColor_xy(ofFloatPixels &pixels, size_t x, size_t y, const ofFloatColor &color){
   pixels.setColor(x,y,color);
}

void ofFloatPixels__setColor_i(ofFloatPixels &pixels, size_t i, const ofFloatColor &color){
   pixels.setColor(i,color);
}

void ofFloatPixels__setColor_all(ofFloatPixels &pixels, const ofFloatColor &color){
   pixels.setColor(color);
}

void ofFloatPixels_flip(ofFloatPixels &pixels, const bool horizontal, const bool vertical){
   ofPixels__flip_pixels(pixels, horizontal, vertical);
}


// 
// Texture
// 

void ofTexture_setTextureWrap__cpp(ofTexture &texture, int i, int j){
   static const GLint TEXTURE_WRAP_MODE[] = {
      GL_CLAMP_TO_EDGE,
      GL_CLAMP_TO_BORDER,
      GL_MIRRORED_REPEAT,
      GL_REPEAT,
      GL_MIRROR_CLAMP_TO_EDGE
   };
   
   texture.setTextureWrap(TEXTURE_WRAP_MODE[i], TEXTURE_WRAP_MODE[j]);
}

void ofTexture_setTextureMinMagFilter__cpp(ofTexture &texture, int i, int j){
   static const GLint TEXTURE_MIN_FILTER_MODES[] = {
      GL_NEAREST,
      GL_LINEAR,
      GL_NEAREST_MIPMAP_NEAREST,
      GL_LINEAR_MIPMAP_NEAREST,
      GL_NEAREST_MIPMAP_LINEAR,
      GL_LINEAR_MIPMAP_LINEAR
   };
   
   static const GLint TEXTURE_MAG_FILTER_MODES[] = {
      GL_NEAREST,
      GL_LINEAR
   };
   
   
   texture.setTextureMinMagFilter(TEXTURE_MIN_FILTER_MODES[i],
                                  TEXTURE_MAG_FILTER_MODES[j]);
}


// 
// Shader
// 

bool shader_load(ofShader &shader, Rice::Array args){
   if(args.size() == 1){
      Rice::Object x = args[0];
      std::string path = from_ruby<std::string>(x);
      return shader.load(path);
      
   }else if(args.size() == 2){
      std::string vert_shader = from_ruby<std::string>(args[0]);
      std::string frag_shader = from_ruby<std::string>(args[1]);
      
      return shader.load(vert_shader, frag_shader, "");
      
   }else if(args.size() == 3){
      // shader.load(vert_shader, frag_shader, geom_shader);
      return false;
      
   }
   
   return false;
}

void ofShader__setUniformTexture(ofShader &shader, const string &name, const ofTexture &img, int textureLocation){
   shader.setUniformTexture(name, img, textureLocation);
}


// 
// Material
// 

void ofMaterial__setDiffuseColor(ofMaterial& mat, ofFloatColor& c){
   // mat.setDiffuseColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   mat.setDiffuseColor(c);
}


void ofMaterial__setSpecularColor(ofMaterial& mat, ofFloatColor& c){
   // mat.setSpecularColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   mat.setSpecularColor(c);
}

void ofMaterial__setAmbientColor(ofMaterial& mat, ofFloatColor& c){
   // mat.setAmbientColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   mat.setAmbientColor(c);
}

void ofMaterial__setEmissiveColor(ofMaterial& mat, ofFloatColor& c){
   // mat.setEmissiveColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   mat.setEmissiveColor(c);
}


// 
// Mesh
// 

void ofMesh__setMode(ofMesh &mesh, int code)
{
   
   // /home/ravenskrag/Desktop/gem_structure/ext/openFrameworks/libs/openFrameworks/graphics/ofGraphicsConstants.h
   
   static const ofPrimitiveMode MESH_MODES[] = {
      OF_PRIMITIVE_TRIANGLES,
      OF_PRIMITIVE_TRIANGLE_STRIP,
      OF_PRIMITIVE_TRIANGLE_FAN,
      OF_PRIMITIVE_LINES,
      OF_PRIMITIVE_LINE_STRIP,
      OF_PRIMITIVE_LINE_LOOP,
      OF_PRIMITIVE_POINTS
   };
   
   mesh.setMode(MESH_MODES[code]);
}

void ofMesh_generateNormals(ofMesh &mesh){
   mesh.addNormals(mesh.getFaceNormals(TRUE));
}



void ofMesh_draw__cpp(ofMesh &mesh, int code){
   static const ofPolyRenderMode MESH_MODES[] = {
      OF_MESH_POINTS,
      OF_MESH_WIREFRAME,
      OF_MESH_FILL
   };
   
   mesh.draw(MESH_MODES[code]);
}

void ofVboMesh_draw_instanced__cpp(ofVboMesh &mesh, int code, int instances){
   static const ofPolyRenderMode MESH_MODES[] = {
      OF_MESH_POINTS,
      OF_MESH_WIREFRAME,
      OF_MESH_FILL
   };
   
   mesh.drawInstanced(MESH_MODES[code], instances);
}




// 
// Light
// 


// ofLight expects ofColor_<float> and openframeworks can make that conversion
// However, Rice can not make this conversion, which creates a runtime error.
// Thus, the following glue code.

   // ofColor will auto convert to ofFloatColor as necessary
   // https://forum.openframeworks.cc/t/relation-between-mesh-addvertex-and-addcolor/31314/3
   
   // Conversion is explaned in documentation for ofColor_
   // (this is the template class, not to be confused with ofColor, 
   // which is merely a shortcut for ofColor_<unsigned char>)
   // 
   // src: https://openframeworks.cc/documentation/types/ofColor/#!show_ofColor_

void ofLight__setDiffuseColor(ofLight& light, ofFloatColor c){
   // light.setDiffuseColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   light.setDiffuseColor(c);
}

void ofLight__setSpecularColor(ofLight& light, ofFloatColor c){
   // light.setSpecularColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   light.setSpecularColor(c);
}

void ofLight__setAmbientColor(ofLight& light, ofFloatColor c){
   // light.setAmbientColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   light.setAmbientColor(c);
}

ofFloatColor ofLight__getDiffuseColor(ofLight& light){
   return light.getDiffuseColor();
}







// template<>
// ofColor_<float> from_ruby<ofColor_<float>>(Object x){
//    int r = x.call("r");
//    int g = x.call("g");
//    int b = x.call("b");
//    int a = x.call("a");
   
//    return ofColor_<float>(r,g,b,a);
// }












// 
// 
// Main bindings start here
// 
// 

void Init_rubyOF_GraphicsAdv(Rice::Module rb_mRubyOF){
   // https://stackoverflow.com/questions/6733934/what-does-immediate-mode-mean-in-opengl
   // http://openframeworks.cc/ofBook/chapters/advanced_graphics.html
   
   // NOTE: The type of "pointer-to-member-function" is different from "pointer-to-function"
   // src: https://isocpp.org/wiki/faq/pointers-to-members
   
   // ofPolyline
   Data_Type<ofPolyline> rb_cPolyline = 
		define_class_under<ofPolyline>(rb_mRubyOF, "Polyline");
   
   rb_cPolyline
      .define_method("lineTo",
         static_cast< void (ofPolyline::*)
         (const glm::vec3 & p)
         >(&ofPolyline::lineTo)
      )
      .define_method("close",
         &ofPolyline::close
      )
      .define_method("draw",
         &ofPolyline::draw
      )
   ;
      // getBoundingBox
      // isClosed
      // bezierTo
      // quadBezierTo
      // curveTo     (Catmull-Rom splines)
   
   
   // ofPath
   Data_Type<ofPath> rb_cPath = 
		define_class_under<ofPath>(rb_mRubyOF, "Path");
   
   rb_cPath
      .define_method("moveTo",
         static_cast< void (ofPath::*)
         (const glm::vec3 & p)
         >(&ofPath::lineTo)
      )
      // .define_method("lineTo",
      //    static_cast< void (ofPath::*)
      //    (const glm::vec3 & p)
      //    >(&ofPath::lineTo)
      // )
      .define_method("close",
         &ofPath::close
      )
      .define_method("draw",
         static_cast< void (ofPath::*)
         () const
         >(&ofPath::draw) // from ofPath.h: "Calling draw() also calls tessellate()" 
         // (maybe getTessellation() will help if you need to go faster?)
      )
   ;
   //  path.setStrokeColor(ofColor::blue);
   //  path.setFillColor(ofColor::red);
   //  path.setFilled(true);
   //  path.setStrokeWidth(2);
   //  tessellation = path.getTessellation();  // => ofVboMesh
   
   
   
   // 
   // ofImage
   // 
   // The ofImage allows you to load an image from disk, manipulate
   // the pixels, and create an OpenGL texture that you can display and
   // manipulate on the graphics card. Loading a file into the ofImage
   // allocates an ofPixels object and creates the ofTexture to display
   // the pixels. 
   
   
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
      
      .define_method("width",  &ofImage::getWidth)
      .define_method("height", &ofImage::getHeight)
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
   
   
   
   
   
   Data_Type<ofPixels> rb_cPixels = 
      define_class_under<ofPixels>(rb_mRubyOF, "Pixels");
   
   rb_cPixels
      .define_constructor(Constructor<ofPixels>())
      .define_method("allocate",
         static_cast< void (ofPixels::*)
         (size_t w, size_t h, ofPixelFormat pixelFormat)
         >(&ofPixels::allocate),
         (
            Arg("width"),
            Arg("height"),
            Arg("pixelFormat") = OF_PIXELS_RGBA
         )
      )
      .define_method("crop",          &ofPixels::crop)
      .define_method("cropTo",        &ofPixels::cropTo)
      .define_method("setColor_i",    &ofPixels__setColor_i)
      // ^ I think set_i actually fills an entire channel?
      //   see ext/openFrameworks/libs/openFrameworks/graphics/ofTrueTypeFont.cpp:837-840
      .define_method("getColor_xy",   &ofPixels__getColor_xy)
      .define_method("setColor_all",  &ofPixels__setColor_all)      
      
      .define_method("setColor_xy",   &ofPixels__setColor_xy)
      .define_method("getPixelIndex", &ofPixels::getPixelIndex)
      .define_method("getTotalBytes", &ofPixels::getTotalBytes)
      
      .define_method("size",          &ofPixels::size) // total num pixels
      .define_method("width",         &ofPixels::getWidth)
      .define_method("height",        &ofPixels::getHeight)
      
      .define_method("flip",          &ofPixels_flip)
   ;
   
   
   
   
   Data_Type<ofFloatPixels> rb_cFloatPixels = 
      define_class_under<ofFloatPixels>(rb_mRubyOF, "FloatPixels");
   
   rb_cFloatPixels
      .define_constructor(Constructor<ofFloatPixels>())
      .define_method("allocate",
         static_cast< void (ofFloatPixels::*)
         (size_t w, size_t h, ofPixelFormat pixelFormat)
         >(&ofFloatPixels::allocate),
         (
            Arg("width"),
            Arg("height"),
            Arg("pixelFormat") = OF_PIXELS_RGBA
         )
      )
      .define_method("crop",          &ofFloatPixels::crop)
      .define_method("crop_to",       &ofFloatPixels::cropTo)
      
      
      
      .define_method("setColor_i",    &ofFloatPixels__setColor_i)
      // ^ I think set_i actually fills an entire channel?
      //   see ext/openFrameworks/libs/openFrameworks/graphics/ofTrueTypeFont.cpp:837-840
      
      .define_method("setColor_xy",   &ofFloatPixels__setColor_xy)
      .define_method("setColor_all",  &ofFloatPixels__setColor_all)
      
      .define_method("getColor_xy",   &ofFloatPixels__getColor_xy)
      .define_method("getPixelIndex", &ofFloatPixels::getPixelIndex)
      .define_method("getTotalBytes", &ofFloatPixels::getTotalBytes)
      
      .define_method("size",          &ofFloatPixels::size) // total num pixels
      .define_method("width",         &ofFloatPixels::getWidth)
      .define_method("height",        &ofFloatPixels::getHeight)
      
      .define_method("flip",          &ofFloatPixels_flip)
      
      .define_method("paste_into",    &ofFloatPixels::pasteInto)
   ;
   
   
   
   
   
   Data_Type<ofTexture> rb_cTexture = 
		define_class_under<ofTexture>(rb_mRubyOF, "Texture");
   
   rb_cTexture
      .define_constructor(Constructor<ofTexture>())
      
      .define_method("draw_wh",
         static_cast< void (ofTexture::*)
         (float x, float y, float z, float w, float h) const
         >(&ofTexture::draw)
      )
      
      .define_method("bind",
         static_cast< void (ofTexture::*)
         (int) const
         >(&ofTexture::bind),
         (
				Arg("textureLocation") = 0
			)
      )
      .define_method("unbind",
         static_cast< void (ofTexture::*)
         (int) const
         >(&ofTexture::unbind),
         (
				Arg("textureLocation") = 0
			)
      )
      .define_method("readToPixels",
         static_cast< void (ofTexture::*)
         (ofPixels &pixels) const
         >(&ofTexture::readToPixels)
      )
      
      .define_method("loadData_Pixels",
         static_cast< void (ofTexture::*)
         (const ofPixels &pix)
         >(&ofTexture::loadData)
      )
      .define_method("loadData_FloatPixels",
         static_cast< void (ofTexture::*)
         (const ofFloatPixels &pix)
         >(&ofTexture::loadData)
      )
      
      
      .define_method("setTextureWrap__cpp",
         &ofTexture_setTextureWrap__cpp)
      
      .define_method("setTextureMinMagFilter__cpp",
         &ofTexture_setTextureMinMagFilter__cpp)
      
      
      .define_method("width",  &ofTexture::getWidth)
      .define_method("height", &ofTexture::getHeight)
      
      .define_method("enableMipmap", &ofTexture::enableMipmap)
      .define_method("disableMipmap", &ofTexture::disableMipmap)
   ;
   
   
   
   
   
   Data_Type<ofShader> rb_cShader = 
      define_class_under<ofShader>(rb_mRubyOF, "Shader");
   
   rb_cShader
      .define_constructor(Constructor<ofShader>())
      .define_method("begin", &ofShader::begin)
      .define_method("end",   &ofShader::end)
      
      
      .define_method("load_shaders__cpp",  &shader_load)
      // either 1 string if the fragment shaders have the same name
      //    i.e. "dof.vert" and "dof.frag"
      // or up to 3 strings if the shaders have different names
      //    i.e ("dof.vert", "dof.frag", "dof.geom")
      // (geometry shader is optional)
      
      // ^ using helper function instead of casting the funciton pointer because the default argument is boost::filesystem::path, which I don't want to bind in Rice
      
      .define_method("isLoaded",  &ofShader::isLoaded)
      
      
      
      
      
      .define_method("setUniform1i",  &ofShader::setUniform1i)
      .define_method("setUniform2i",  &ofShader::setUniform2i)
      .define_method("setUniform3i",  &ofShader::setUniform3i)
      .define_method("setUniform4i",  &ofShader::setUniform4i)
      
      // .define_method("setUniform1f",  &ofShader::setUniform1f)
      // .define_method("setUniform2f",  
      //    static_cast< void (ofShader::*)
      //    (const string &name, float v1, float v2)
      //    >(&ofShader::setUniform2f)
      // )
      // .define_method("setUniform3f",  
      //    static_cast< void (ofShader::*)
      //    (const string &name, float v1, float v2, float v3)
      //    >(&ofShader::setUniform3f)
      // )
      // .define_method("setUniform4f",  
      //    static_cast< void (ofShader::*)
      //    (const string &name, float v1, float v2, float v3, float v4)
      //    >(&ofShader::setUniform4f)
      // )
      
      
      .define_method("setUniformTexture", &ofShader__setUniformTexture)
      // (the textureLocation is just the slot number)
      
      
      // .define_method("load_oneNameVertAndFrag",
      //    static_cast< bool (ofShader::*)
      //    (const filesystem::path &shaderName)
      //    >(&ofShader::load)
      // )
      
      // .define_method("load_VertFragGeom",
      //    static_cast< bool (ofShader::*)
      //    (const filesystem::path &vertName, const filesystem::path &fragName, const filesystem::path &geomName)
      //    >(&ofShader::load),
      //    (
      //       Arg("vert_shader"),
      //       Arg("frag_shader"),
      //       Arg("geom_shader") = ""
      //    )
      // )
   ;
   
   
   
   
   
   
   Data_Type<ofMaterial> rb_cMaterial = 
      define_class_under<ofMaterial>(rb_mRubyOF, "Material");
   
   rb_cMaterial
      .define_constructor(Constructor<ofMaterial>())
      // setup
      
      .define_method("begin", &ofMaterial::begin)
      .define_method("end",   &ofMaterial::end)
      
      .define_method("ambient_color=",    &ofMaterial__setAmbientColor)
      .define_method("diffuse_color=",    &ofMaterial__setDiffuseColor)
      .define_method("specular_color=",   &ofMaterial__setSpecularColor)
      .define_method("emissive_color=",   &ofMaterial__setEmissiveColor)
      .define_method("shininess=",        &ofMaterial::setShininess)
      
      .define_method("ambient_color",     &ofMaterial::getAmbientColor)
      .define_method("diffuse_color",     &ofMaterial::getDiffuseColor)
      .define_method("specular_color",    &ofMaterial::getSpecularColor)
      .define_method("emissive_color",    &ofMaterial::getEmissiveColor)
      .define_method("shininess",         &ofMaterial::getShininess)      
   ;
   
   
   
   
   
   
   // ofMesh
   Data_Type<ofMesh> rb_cMesh = 
		define_class_under<ofMesh>(rb_mRubyOF, "Mesh");
   
   rb_cMesh
      .define_constructor(Constructor<ofMesh>())
      .define_method("draw__cpp",         &ofMesh_draw__cpp)
      
      .define_method("clear",             &ofMesh::clear)
      
      .define_method("setMode",           &ofMesh__setMode)
      .define_method("addVertex",         &ofMesh::addVertex)
      .define_method("addNormal",         &ofMesh::addNormal)
      .define_method("addTexCoord",       &ofMesh::addTexCoord)
      .define_method("addIndex",          &ofMesh::addIndex)
      
      .define_method("vertex_count",      &ofMesh::getNumVertices)
      
      
      // .define_method("addNormals",
      //    static_cast< void (ofMesh::*)
      //    (const std::vector<ofDefaultNormalType> &norms) const
      //    >(&ofMesh::addNormals)
      // )
      // .define_method("getFaceNormals",    &ofMesh::getFaceNormals)
      
      .define_method("generate_normals",    &ofMesh_generateNormals)
      
      // .define_method(
      //    "addColor",
      //    static_cast< void (ofMesh::*)
      //    (ofColor)
      //    >(&ofMesh::addColor)
      // )
      // ^ expects ofColor_<float> but I have bound ofColor_<unsigned char>
   ;
   
   
   // NOTE: ofMesh will work with both programmable renderer and fixed funcction pipeline. However, when using programmable renderer, the verts need to all be copied into a VBO before rendering. Thus, when using programable renderer, ofVboMesh tends to be faster than ofMesh.
   
   // NOTE: ofVboMesh is a subclass of ofMesh and Ruby bindings reflect this.
   
   
   // ofVboMesh
   Data_Type<ofVboMesh> rb_cVboMesh = 
		define_class_under<ofVboMesh, ofMesh>(rb_mRubyOF, "VboMesh");
   
   rb_cVboMesh
      .define_constructor(Constructor<ofVboMesh>())
      .define_method("draw_instanced__cpp",  &ofVboMesh_draw_instanced__cpp)
   ;
   
   
   
   
   // ofNode
   Data_Type<ofNode> rb_cNode = 
      define_class_under<ofNode>(rb_mRubyOF, "Node");
   
   rb_cNode
      .define_constructor(Constructor<ofNode>())
      .define_method(
         "transformGL",
         static_cast< void (ofNode::*)
         (ofBaseRenderer * renderer) const
         >(&ofNode::transformGL),
         (
            
            Arg("renderer")    = nullptr
         )
      )
      
      .define_method(
         "restoreTransformGL",
         static_cast< void (ofNode::*)
         (ofBaseRenderer * renderer) const
         >(&ofNode::restoreTransformGL),
         (
            
            Arg("renderer")    = nullptr
         )
      )
      
      
      .define_method("position",
         static_cast< glm::vec3 (ofNode::*)
         (void) const
         >(&ofNode::getPosition)
      )
      .define_method("position=",
         static_cast< void (ofNode::*)
         (const glm::vec3 &p)
         >(&ofNode::setPosition)
      )
      
      
      .define_method("scale",
         static_cast< glm::vec3 (ofNode::*)
         (void) const
         >(&ofNode::getScale)
      )
      .define_method("scale=",
         static_cast< void (ofNode::*)
         (const glm::vec3 &p)
         >(&ofNode::setScale)
      )
      
      .define_method("parent",     &ofNode::getParent)
      .define_method("parent=",    &ofNode::setParent)
      
      
      .define_method("orientation",
         static_cast< glm::quat (ofNode::*)
         () const
         >(&ofNode::getOrientationQuat)
      )
      .define_method("orientation=",
         static_cast< void (ofNode::*)
         (const glm::quat &q)
         >(&ofNode::setOrientation)
      )
      
      
      .define_method("lookAt",
         static_cast< void (ofNode::*)
         (const glm::vec3 &lookAtPosition)
         >(&ofNode::lookAt)
      )
      // there's another variation where you can specify up vector
      // but I don't understand the coordinate system right now so...
      
      
      
      .define_method("draw", &ofNode::draw)
      // calls the virtual function customDraw
      // which is used by some OF core classes, such as ofLight.
   ;
   
   
   
   
   // ofCamera
   Data_Type<ofCamera> rb_cCamera = 
		define_class_under<ofCamera, ofNode>(rb_mRubyOF, "Camera");
   
   rb_cCamera
      .define_constructor(Constructor<ofCamera>())
      // near
      // far
      // fov
      // aspect
      .define_method("near_clip",      &ofCamera::getNearClip)
      .define_method("far_clip",       &ofCamera::getFarClip)
      .define_method("fov",           &ofCamera::getFov)
      .define_method("aspect_ratio",   &ofCamera::getAspectRatio)
      
      .define_method("near_clip=",      &ofCamera::setNearClip)
      .define_method("far_clip=",       &ofCamera::setFarClip)
      .define_method("fov=",           &ofCamera::setFov)
      .define_method("aspect_ratio=",   &ofCamera::setAspectRatio)
      
      .define_method("forceAspectRatio?",   &ofCamera::getForceAspectRatio)
      .define_method("forceAspectRatio=",   &ofCamera::setForceAspectRatio)
      
      .define_method("begin",
         static_cast< void (ofCamera::*)
         (void)
         >(&ofCamera::begin)
      )
      .define_method("end",     &ofCamera::end)
      
      
      .define_method("ortho?",         &ofCamera::getOrtho)
      .define_method("enableOrtho",    &ofCamera::getOrtho)
      .define_method("disableOrtho",   &ofCamera::getOrtho)
   ;
   
   
   // of3dPrimitive
   Data_Type<of3dPrimitive> rb_c3dPrimitive = 
		define_class_under<of3dPrimitive>(rb_mRubyOF, "OF_3dPrimitive");
   
   
   
   
   Data_Type<ofLight> rb_cLight = 
      define_class_under<ofLight, ofNode>(rb_mRubyOF, "Light");
   
   rb_cLight
      .define_constructor(Constructor<ofLight>())
      .define_method("setup",         &ofLight::setup)
      .define_method("enable",        &ofLight::enable)
      .define_method("disable",       &ofLight::disable)
      .define_method("enabled?",      &ofLight::getIsEnabled)
      
      
      // point
      // spot
      // directional
      // area
      .define_method("getIsAreaLight",    &ofLight::getIsAreaLight)
      .define_method("getIsDirectional",  &ofLight::getIsDirectional)
      .define_method("getIsPointLight",   &ofLight::getIsPointLight)
      .define_method("getIsSpotlight",    &ofLight::getIsSpotlight)
      
      .define_method("setAreaLight",      &ofLight::setAreaLight)
      .define_method("setDirectional",    &ofLight::setDirectional)
      .define_method("setPointLight",     &ofLight::setPointLight)
      .define_method("setSpotlight",      &ofLight::setSpotlight)
      
      .define_method("getLightID",        &ofLight::getLightID)
      
      
      .define_method("diffuse_color=",    &ofLight__setDiffuseColor)
      .define_method("specular_color=",   &ofLight__setSpecularColor)
      .define_method("ambient_color=",    &ofLight__setAmbientColor)
      
      // .define_method("ofSetGlobalAmbientColor",   &ofSetGlobalAmbientColor)
      
      .define_method("diffuse_color",     &ofLight__getDiffuseColor)
   ;
}

