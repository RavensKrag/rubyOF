#include "ofMesh.h"
#include "Mesh.h"

using namespace Rice;

Rice::Class Init_rubyOF_mesh(Rice::Module rb_mRubyOF)
{
	Data_Type<ofMesh> rb_cMesh = 
		define_class_under<ofMesh>(rb_mRubyOF, "Mesh");
	
	
	// typedef void (ofFbo::*ofFbo_allocWRAP)(int,int,int,int) const;
	// typedef void (ofFbo::*ofFbo_begin)() const;
	
	rb_cMesh
      .define_constructor(Constructor<ofMesh>())
		
		// // .define_method("allocate",  ofFbo_allocWRAP(&ofFbo::allocate))
		// .define_method("allocate",  &ofFbo_allocate_from_struct)
		
      
      
		// from ofFbo.h:
			/// \brief    Sets up the framebuffer and binds it for rendering.
			/// \warning  This is a convenience method, and is considered unsafe 
			///           in multi-window and/or multi-renderer scenarios.
			///           If you use more than one renderer, use each renderer's
			///           explicit void ofBaseGLRenderer::begin(const ofFbo & fbo, bool setupPerspective) 
			///           method instead.
			/// \sa       void ofBaseGLRenderer::begin(const ofFbo & fbo, bool setupPerspective)
		
		
		// .define_method("begin",
		// 	static_cast<void (ofFbo::*)(ofFboBeginMode)>(&ofFbo::begin),
		// 	(
		// 		Arg("mode") = ofFboBeginMode::Perspective | ofFboBeginMode::MatrixFlip
		// 	)
		// )
		
		// .define_method("end",       &ofFbo::end)
		// .define_method("bind",      &ofFbo::bind)
		// .define_method("unbind",    &ofFbo::unbind)
		
		// .define_method("draw_xy",
		// 	static_cast< void (ofFbo::*)
		// 	(float x, float y) const
		// 	>(&ofFbo::draw)
		// )
		// .define_method("draw_xywh",
		// 	static_cast< void (ofFbo::*)
		// 	(float x, float y, float width, float height) const
		// 	>(&ofFbo::draw)
		// )
	;
	
	
	
	return rb_cMesh;
}
