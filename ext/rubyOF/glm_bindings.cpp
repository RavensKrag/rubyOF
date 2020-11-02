#include "ofMain.h"
#include "glm_bindings.h"

using namespace Rice;


float glm_vec2_getComponent(glm::vec2& p, int i){
   return p[i];
}

void  glm_vec2_setComponent(glm::vec2& p, int i, float value){
   p[i] = value;
}

float glm_vec3_getComponent(glm::vec3& p, int i){
   return p[i];
}

void  glm_vec3_setComponent(glm::vec3& p, int i, float value){
   p[i] = value;
}

float glm_vec4_getComponent(glm::vec4& p, int i){
   return p[i];
}

void  glm_vec4_setComponent(glm::vec4& p, int i, float value){
   p[i] = value;
}

float glm_quat_getComponent(glm::quat& p, int i){
   return p[i];
}

void  glm_quat_setComponent(glm::quat& p, int i, float value){
   p[i] = value;
}


glm::mat4 glm_mat4_mult__mat4(const glm::mat4 &self, const glm::mat4 &m){
   return self*m;
}

glm::mat4 glm_ortho__float(
   float const& left, float const& right,
   float const& bottom, float const& top,
   float const& zNear, float const& zFar)
{
   return glm::ortho(left, right, bottom, top, zNear, zFar);
}


Module Init_GLM(){
   Module rb_mGLM = define_module("GLM");
   
   // 
   // vec2
   // 
   
   Data_Type<glm::vec2> rb_cGLM_vec2 =
      define_class_under<glm::vec2>(rb_mGLM, "Vec2");
   
   rb_cGLM_vec2
      .define_constructor(Constructor<glm::vec2, float, float>())
      .define_method("get_component",   &glm_vec2_getComponent)
      .define_method("set_component",   &glm_vec2_setComponent)
   ;
   
   // 
   // vec3
   // 
   
   // Vec3f is exactly the same as ofPoint. If you try to bind both,
   // Rice gets mad, and you get a runtime error.
   Data_Type<glm::vec3> rb_cGLM_vec3 =
      define_class_under<glm::vec3>(rb_mGLM, "Vec3");
   
   rb_cGLM_vec3
      .define_constructor(Constructor<glm::vec3, float, float, float>())
      .define_method("get_component",   &glm_vec3_getComponent)
      .define_method("set_component",   &glm_vec3_setComponent)
   ;
   
   // 
   // vec4
   // 
   
   Data_Type<glm::vec4> rb_cGLM_vec4 = 
      define_class_under<glm::vec4>(rb_mGLM, "Vec4");
   
   rb_cGLM_vec4
      .define_constructor(Constructor<glm::vec4, float, float, float, float>())
      .define_method("get_component",   &glm_vec4_getComponent)
      .define_method("set_component",   &glm_vec4_getComponent)
   ;
   
   // 
   // mat3
   // 
   
   Data_Type<glm::mat3> rb_cGLM_mat3 = 
      define_class_under<glm::mat3>(rb_mGLM, "Mat3");
   
   rb_cGLM_mat3
      .define_constructor(Constructor<glm::mat3, 
                              const glm::vec3&,
                              const glm::vec3&,
                              const glm::vec3&>())
   ;
   
   // 
   // mat4
   // 
   
   Data_Type<glm::mat4> rb_cGLM_mat4 = 
      define_class_under<glm::mat4>(rb_mGLM, "Mat4");
   
   rb_cGLM_mat4
      .define_constructor(Constructor<glm::mat4, 
                              const glm::vec4&,
                              const glm::vec4&,
                              const glm::vec4&,
                              const glm::vec4&>())
      
      .define_method("*",  &glm_mat4_mult__mat4)
      
   ;
   
   
   // 
   // quaternion
   // 
   
   Data_Type<glm::quat> rb_cGLM_quat = 
      define_class_under<glm::quat>(rb_mGLM, "Quat");
   
   rb_cGLM_quat
      .define_constructor(Constructor<glm::quat, float, float, float, float>())
      .define_method("get_component",   &glm_quat_getComponent)
      .define_method("set_component",   &glm_quat_getComponent)
   ;
   
   
   // 
   // conversions etc
   // 
   
   rb_mGLM
      // https://stackoverflow.com/questions/38145042/quaternion-to-matrix-using-glm
      .define_singleton_method("toMat4__quat",
         static_cast< glm::mat4 (*)
         (const glm::quat &p)
         >(&glm::toMat4)
      )
      
      // from OpenFrameworks documentation
      .define_singleton_method("quat_cast__mat3",
         static_cast< glm::quat (*)
         (const glm::mat3 &p)
         >(&glm::quat_cast)
      )
      .define_singleton_method("quat_cast__mat4",
         static_cast< glm::quat (*)
         (const glm::mat3 &p)
         >(&glm::quat_cast)
      )
      
      
      
      .define_singleton_method("inverse__mat3",
         static_cast< glm::mat3 (*)
         (const glm::mat3 &m)
         >(&glm::inverse)
      )
      
      .define_singleton_method("inverse__mat4",
         static_cast< glm::mat4 (*)
         (const glm::mat4 &m)
         >(&glm::inverse)
      )
      
      .define_singleton_method("inverse__quat",
         static_cast< glm::quat (*)
         (const glm::quat &p)
         >(&glm::inverse)
      )
      
      
      
      
      .define_singleton_method("translate",
         static_cast< glm::mat4 (*)
         (const glm::mat4 &m, const glm::vec3 &t)
         >(&glm::translate)
      )
      
      
      
      // https://stackoverflow.com/questions/12230312/is-glmortho-actually-wrong
      .define_singleton_method("ortho",   &glm_ortho__float)
   ;
   
   
   return rb_mGLM;
   
}

