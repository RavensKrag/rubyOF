#include "ofMesh.h"
#include "Mesh.h"

using namespace Rice;

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


Rice::Class Init_rubyOF_mesh(Rice::Module rb_mRubyOF)
{
	Data_Type<ofMesh> rb_cMesh = 
		define_class_under<ofMesh>(rb_mRubyOF, "Mesh");
	
	
	// typedef void (ofFbo::*ofFbo_allocWRAP)(int,int,int,int) const;
	// typedef void (ofFbo::*ofFbo_begin)() const;
	
	rb_cMesh
      .define_constructor(Constructor<ofMesh>())
		
		.define_method("setMode",           ofMesh__setMode)
		.define_method("addVertex",         &ofMesh::addVertex)
		.define_method("addTexCoord",       &ofMesh::addTexCoord)
		.define_method("addIndex",          &ofMesh::addIndex)
		
		
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
