#include "ofMain.h"
#include "GraphicsAdvanced.h"

using namespace Rice;


Rice::Module Init_rubyOF_GraphicsAdv(Rice::Module rb_mRubyOF){
   Module rb_mGLM = define_module("GLM");
   
   Data_Type<glm::vec3> rb_cGLM_vec3 = 
		define_class_under<glm::vec3>(rb_mGLM, "vec3");
   
   
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
      .define_method("lineTo",
         static_cast< void (ofPath::*)
         (const glm::vec3 & p)
         >(&ofPath::lineTo)
      )
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
   
   
   // ofMesh
   Data_Type<ofMesh> rb_cMesh = 
		define_class_under<ofMesh>(rb_mRubyOF, "Mesh");
   
   rb_cMesh
      .define_method("draw",
         static_cast< void (ofMesh::*)
         () const
         >(&ofMesh::draw)
      )
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
   
   // of3dPrimitive
   Data_Type<of3dPrimitive> rb_c3dPrimitive = 
		define_class_under<of3dPrimitive>(rb_mRubyOF, "OF_3dPrimitive");
   
   
   
   return rb_mGLM;
}
