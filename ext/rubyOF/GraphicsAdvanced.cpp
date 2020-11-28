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






// ofLight expects ofColor_<float> but openframeworks can make that conversion

      // ofColor will auto convert to ofFloatColor as necessary
      // https://forum.openframeworks.cc/t/relation-between-mesh-addvertex-and-addcolor/31314/3
      
//   The issue is that Rice can not make this conversion,
//   which creates a runtime error.

// Conversion is explaned in documentation for ofColor_
// (this is the template class, not to be confused with ofColor, 
// which is merely a shortcut for ofColor_<unsigned char>)
// src: https://openframeworks.cc/documentation/types/ofColor/#!show_ofColor_
void ofLight__setDiffuseColor(ofLight& light, ofColor_<unsigned char>& c){
   // light.setDiffuseColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   ofFloatColor c2(c);
   light.setDiffuseColor(c2);
}

void ofLight__setSpecularColor(ofLight& light, ofColor_<unsigned char>& c){
   // light.setSpecularColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   ofFloatColor c2(c);
   light.setSpecularColor(c2);
}

void ofLight__setAmbientColor(ofLight& light, ofColor_<unsigned char>& c){
   // light.setAmbientColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   ofFloatColor c2(c);
   light.setAmbientColor(c2);
}

ofColor_<unsigned char> ofLight__getDiffuseColor(ofLight& light){
   ofColor_<float> c_float = light.getDiffuseColor();
   
   ofColor_<unsigned char> c_char(c_float);
   
   return c_char;
}





void ofMaterial__setDiffuseColor(ofMaterial& mat, ofColor_<unsigned char>& c){
   // mat.setDiffuseColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   ofFloatColor c2(c);
   mat.setDiffuseColor(c2);
}


void ofMaterial__setSpecularColor(ofMaterial& mat, ofColor_<unsigned char>& c){
   // mat.setSpecularColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   ofFloatColor c2(c);
   mat.setSpecularColor(c2);
}

void ofMaterial__setAmbientColor(ofMaterial& mat, ofColor_<unsigned char>& c){
   // mat.setAmbientColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   ofFloatColor c2(c);
   mat.setAmbientColor(c2);
}

void ofMaterial__setEmissiveColor(ofMaterial& mat, ofColor_<unsigned char>& c){
   // mat.setEmissiveColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   ofFloatColor c2(c);
   mat.setEmissiveColor(c2);
}



// template<>
// ofColor_<float> from_ruby<ofColor_<float>>(Object x){
//    int r = x.call("r");
//    int g = x.call("g");
//    int b = x.call("b");
//    int a = x.call("a");
   
//    return ofColor_<float>(r,g,b,a);
// }





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
      .define_method("loadData",
         static_cast< void (ofTexture::*)
         (const ofPixels &pix)
         >(&ofTexture::loadData)
      )
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
      
      .define_method("ambient_color",     &ofMaterial::setAmbientColor)
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
      
      .define_method("setMode",           &ofMesh__setMode)
      .define_method("addVertex",         &ofMesh::addVertex)
      .define_method("addNormal",         &ofMesh::addNormal)
      .define_method("addTexCoord",       &ofMesh::addTexCoord)
      .define_method("addIndex",          &ofMesh::addIndex)
      
      
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

