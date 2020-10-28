#include "ofMain.h"
#include "GraphicsAdvanced.h"

using namespace Rice;

#include "rice/Array.hpp"

bool shader_load(ofShader &shader, Rice::Array args){
   if(args.size() == 1){
      Rice::Object x = args[0];
      std::string path = from_ruby<std::string>(x);
      return shader.load(path);
   }else if(args.size() == 2 || args.size() == 3){
      return false;
   }
   
   return false;
}

void ofShader__setUniformTexture(ofShader &shader, const string &name, const ofTexture &img, int textureLocation){
   shader.setUniformTexture(name, img, textureLocation);
}



ofColor ofPixels__getColor_xy(ofPixels &pixels, size_t x, size_t y){
   return pixels.getColor(x,y);
}

void ofPixels__setColor_xy(ofPixels &pixels, size_t x, size_t y, const ofColor &color){
   pixels.setColor(x,y,color);
}

void ofPixels__setColor_i(ofPixels &pixels, size_t i, const ofColor &color){
   pixels.setColor(i,color);
}



void ofMesh__setMode(ofMesh mesh, Rice::Symbol mode)
{
   
   // /home/ravenskrag/Desktop/gem_structure/ext/openFrameworks/libs/openFrameworks/graphics/ofGraphicsConstants.h
   ofPrimitiveMode m;
   if(mode == Rice::Symbol("OF_PRIMITIVE_TRIANGLES")){
      m = OF_PRIMITIVE_TRIANGLES;
   }else if(mode == Rice::Symbol("OF_PRIMITIVE_TRIANGLE_STRIP")){
      m = OF_PRIMITIVE_TRIANGLE_STRIP;
   }else if(mode == Rice::Symbol("OF_PRIMITIVE_TRIANGLE_FAN")){
      m = OF_PRIMITIVE_TRIANGLE_FAN;
   }else if(mode == Rice::Symbol("OF_PRIMITIVE_LINES")){
      m = OF_PRIMITIVE_LINES;
   }else if(mode == Rice::Symbol("OF_PRIMITIVE_LINE_STRIP")){
      m = OF_PRIMITIVE_LINE_STRIP;
   }else if(mode == Rice::Symbol("OF_PRIMITIVE_LINE_LOOP")){
      m = OF_PRIMITIVE_LINE_LOOP;
   }else if(mode == Rice::Symbol("OF_PRIMITIVE_POINTS")){
      m = OF_PRIMITIVE_POINTS;
   }
   
   mesh.setMode(m);
}








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
   
   
   
   Data_Type<ofShader> rb_cShader = 
      define_class_under<ofShader>(rb_mRubyOF, "Shader");
   
   rb_cShader
      .define_constructor(Constructor<ofShader>())
      .define_method("begin", &ofShader::begin)
      .define_method("end",   &ofShader::end)
      
      
      .define_method("load",  &shader_load)
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
      .define_method("getColor_xy",   &ofPixels__getColor_xy)
      
      .define_method("setColor_i",    &ofPixels__setColor_i)
      // ^ I think set_i actually fills an entire channel?
      //   see ext/openFrameworks/libs/openFrameworks/graphics/ofTrueTypeFont.cpp:837-840
      
      .define_method("setColor_xy",   &ofPixels__setColor_xy)
      .define_method("getPixelIndex", &ofPixels::getPixelIndex)
      .define_method("getTotalBytes", &ofPixels::getTotalBytes)
      
      .define_method("size",          &ofPixels::size) // total num pixels
      .define_method("width",          &ofPixels::getWidth)
      .define_method("height",          &ofPixels::getHeight)
   ;
   
   
   
   Data_Type<ofTexture> rb_cTexture = 
		define_class_under<ofTexture>(rb_mRubyOF, "Texture");
   
   rb_cTexture
      .define_constructor(Constructor<ofTexture>())
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
         >(&ofTexture::bind),
         (
				Arg("textureLocation") = 0
			)
      )
      .define_method("readToPixels",
         static_cast< void (ofTexture::*)
         (ofPixels &pixels) const
         >(&ofTexture::readToPixels)
      )
      .define_method("loadData",
         static_cast< void (ofTexture::*)
         (const ofPixels &pix)
         >(&ofTexture::loadData)
      )
   ;
   
   
   
   // ofNode
   Data_Type<ofNode> rb_cNode = 
      define_class_under<ofNode>(rb_mRubyOF, "Node");
   
   rb_cNode
      .define_constructor(Constructor<ofNode>())
      
      .define_method("getPosition",   &ofNode::getPosition)
      .define_method("setPosition",
         static_cast< void (ofNode::*)
         (const glm::vec3 &p)
         >(&ofNode::setPosition)
      )
      
      .define_method("getScale",      &ofNode::getScale)
      .define_method("setScale",
         static_cast< void (ofNode::*)
         (const glm::vec3 &p)
         >(&ofNode::setScale)
      )
      
      .define_method("getParent",     &ofNode::getParent)
      .define_method("setParent",     &ofNode::setParent)
      
      .define_method("lookAt",
         static_cast< void (ofNode::*)
         (const glm::vec3 &lookAtPosition)
         >(&ofNode::lookAt)
      )
       // there's another variation where you can specify up vector
       // but I don't understand the coordinate system right now so...
   ;
   
   
   
   // ofMesh
   Data_Type<ofMesh> rb_cMesh = 
		define_class_under<ofMesh>(rb_mRubyOF, "Mesh");
   
   rb_cMesh
      .define_constructor(Constructor<ofMesh>())
      .define_method("draw",
         static_cast< void (ofMesh::*)
         () const
         >(&ofMesh::draw)
      )
      
      .define_method("setMode",           ofMesh__setMode)
      .define_method("addVertex",         &ofMesh::addVertex)
      .define_method("addTexCoord",       &ofMesh::addTexCoord)
      .define_method("addIndex",          &ofMesh::addIndex)
      
      // .define_method(
      //    "addColor",
      //    static_cast< void (ofMesh::*)
      //    (ofColor)
      //    >(&ofMesh::addColor)
      // )
      // ^ expects ofColor_<float> but I have bound ofColor_<unsigned char>
   ;
   
   // mesh.addVertex(ofVec3f(20,20));
   // mesh.addColor(ofColor::red);
   // mesh.addVertex(ofVec3f(40,20));
   // mesh.addColor(ofColor::red);
   // mesh.addVertex(ofVec3f(40,40));
   // mesh.addColor(ofColor::red);
   // mesh.addVertex(ofVec3f(20,40));
   // mesh.addColor(ofColor::red);
   // mesh.setMode(OF_PRIMITIVE_TRIANGLE_FAN);
   
   
   // ofVboMesh
   Data_Type<ofVboMesh> rb_cVboMesh = 
		define_class_under<ofVboMesh>(rb_mRubyOF, "VboMesh");
   
   rb_cVboMesh
      .define_method("draw",
         static_cast< void (ofVboMesh::*)
         () const
         >(&ofVboMesh::draw)
      )
   ;
   
   // ofMatrix4x4
   // this class is bound in the standard graphics file,
   // as it can also be used in immediate mode
   
   
   
   
   // ofCamera
   Data_Type<ofCamera> rb_cCamera = 
		define_class_under<ofCamera>(rb_mRubyOF, "Camera");
   
   rb_cCamera
      .define_constructor(Constructor<ofCamera>())
      // near
      // far
      // fov
      // aspect
      .define_method("getNearClip",      &ofCamera::getNearClip)
      .define_method("getFarClip",       &ofCamera::getFarClip)
      .define_method("getFov",           &ofCamera::getFov)
      .define_method("getAspectRatio",   &ofCamera::getAspectRatio)
      
      .define_method("setNearClip",      &ofCamera::setNearClip)
      .define_method("setFarClip",       &ofCamera::setFarClip)
      .define_method("setFov",           &ofCamera::setFov)
      .define_method("setAspectRatio",   &ofCamera::setAspectRatio)
      
      
      // need to copy over the methods from ofNode,
      // because for Rice can't do that for you
      .define_method("begin",
         static_cast< void (ofCamera::*)
         (void)
         >(&ofCamera::begin)
      )
      .define_method("end",     &ofCamera::end)
      
      .define_method("getPosition",   &ofCamera::getPosition)
      .define_method("setPosition",
         static_cast< void (ofCamera::*)
         (const glm::vec3 &p)
         >(&ofCamera::setPosition)
      )
      
      .define_method("getScale",      &ofCamera::getScale)
      .define_method("setScale",
         static_cast< void (ofCamera::*)
         (const glm::vec3 &p)
         >(&ofCamera::setScale)
      )
      
      .define_method("getParent",     &ofCamera::getParent)
      .define_method("setParent",     &ofCamera::setParent)
      
      .define_method("lookAt",
         static_cast< void (ofCamera::*)
         (const glm::vec3 &lookAtPosition)
         >(&ofCamera::lookAt)
      )
       // there's another variation where you can specify up vector
       // but I don't understand the coordinate system right now so...
   ;
   
   
   // of3dPrimitive
   Data_Type<of3dPrimitive> rb_c3dPrimitive = 
		define_class_under<of3dPrimitive>(rb_mRubyOF, "OF_3dPrimitive");
   
   
   
   
   Data_Type<ofLight> rb_cLight = 
      define_class_under<ofLight>(rb_mRubyOF, "Light");
   
   rb_cLight
      .define_constructor(Constructor<ofLight>())
      
      .define_method("enable",        &ofLight::enable)
      .define_method("disable",       &ofLight::disable)
      .define_method("getIsEnabled",  &ofLight::getIsEnabled)
      
      
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
      
      
      // need to copy over the methods from ofNode,
      // because for Rice can't do that for you
      .define_method("getPosition",   &ofLight::getPosition)
      .define_method("setPosition",
         static_cast< void (ofLight::*)
         (const glm::vec3 &p)
         >(&ofLight::setPosition)
      )
      
      .define_method("getScale",      &ofLight::getScale)
      .define_method("setScale",
         static_cast< void (ofLight::*)
         (const glm::vec3 &p)
         >(&ofLight::setScale)
      )
      
      .define_method("getParent",     &ofLight::getParent)
      .define_method("setParent",     &ofLight::setParent)
      
      .define_method("lookAt",
         static_cast< void (ofLight::*)
         (const glm::vec3 &lookAtPosition)
         >(&ofLight::lookAt)
      )
       // there's another variation where you can specify up vector
       // but I don't understand the coordinate system right now so...
   ;
}

