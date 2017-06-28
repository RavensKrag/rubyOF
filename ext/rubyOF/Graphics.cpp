#include "ofMain.h"
#include "Graphics.h"

using namespace Rice;

Rice::Module Init_oni_graphics(Rice::Module rb_mOni)
{
	// --- Bind the core types first, and then the interesting methods that use them.
	Data_Type<ofMatrixMode> rb_cMatrixMode = 
		define_class_under<ofMatrixMode>(rb_mOni, "MatrixMode");
	
	Data_Type<ofMatrix4x4> rb_cMatrix4x4 = 
		define_class_under<ofMatrix4x4>(rb_mOni,  "Matrix4x4");
		
		// wrap #set to bind a series of floats to your matrix (it's overloaded)
	
	Data_Type<ofQuaternion> rb_cQuaternion = 
		define_class_under<ofQuaternion>(rb_mOni, "Quaternion");
	
	// Vec3f is exactly the same as ofPoint. If you try to bind both,
	// Rice gets mad, and you get a runtime error.
	
	// Data_Type<ofVec3f> rb_cVec3f = 
	// 	define_class_under<ofVec3f>(rb_mOni,  "Vec3f");
	
	Data_Type<ofVec4f> rb_cVec4f = 
		define_class_under<ofVec4f>(rb_mOni,  "Vec4f");

	
	
	// --- Ok, time to bind some useful stuff.
	Module rb_mGraphics = define_module_under(rb_mOni, "Graphics");
	// ------------------
	// global oF functions
	// ------------------
	
	// these typedefs select one version of a polymorphic interface
	typedef void (*wrap_ofDrawBitmapString)(const std::string& textString, float x, float y, float z);
	
	
	typedef void (*wrap_ofDrawRectangle)(float x,float y,float z,float w,float h);
	typedef void (*wrap_ofDrawCircle)(float x, float y, float z, float radius);
	typedef void (*wrap_ofDrawEllipse)(float x, float y, float z, float width, float height);
	typedef void (*wrap_ofDrawTriangle)(float x1,float y1,float z1,float x2,float y2,float z2,float x3, float y3,float z3);
	typedef void (*wrap_ofDrawLine)(float x1,float y1,float z1,float x2,float y2,float z2);
	
	typedef void (*wrap_ofDrawRectRounded)(float x, float y, float z, float w, float h, float topLeftRadius, float topRightRadius, float bottomRightRadius, float bottomLeftRadius);
	
	typedef void (*wrap_ofClear)(float r, float g, float b, float a);
	// NOTE: clear requires floats, while "ofBackground" takes int? Looks weird, maybe should report?
	
	typedef void (*wrap_ofBackground)(int r, int g, int b, int a);
	typedef void (*wrap_ofBackgroundHex)(int hexColor, int alpha);
	typedef void (*wrap_ofSetColor)(int r, int g, int b, int a);
	typedef void (*wrap_ofSetHexColor)(int hexColor);
	
	typedef void (*wrap_ofTranslate)(float x, float y, float z);
	typedef void (*wrap_ofScale)(float xAmnt, float yAmnt, float zAmnt);
	typedef void (*wrap_ofRotateAroundAxis)
		(float degrees, float vecX, float vecY, float vecZ);
	typedef void (*wrap_matrix_op)(const glm::mat4 & m);
	
	
	rb_mGraphics
		// bitmap string
		.define_method("ofDrawBitmapString", wrap_ofDrawBitmapString(&ofDrawBitmapString))
		
		// draw primatives
		.define_method("ofDrawRectangle",    wrap_ofDrawRectangle(&ofDrawRectangle))
		.define_method("ofDrawCircle",       wrap_ofDrawCircle(&ofDrawCircle))
		.define_method("ofDrawEllipse",      wrap_ofDrawEllipse(&ofDrawEllipse))
		
		.define_method("ofDrawTriangle",
			wrap_ofDrawTriangle(&ofDrawTriangle)
		)
		
		.define_method("ofDrawLine",
			wrap_ofDrawLine(&ofDrawLine)
		)
		
		.define_method("ofDrawRectRounded",
			wrap_ofDrawRectRounded(&ofDrawRectRounded)
		)
		
		// turn filling of primative shapes on / off
		// (used to draw outlines)
		.define_method("ofFill",             &ofFill)
		.define_method("ofNoFill",           &ofNoFill)
		
		// alter line weight
		.define_method("ofSetLineWidth",     &ofSetLineWidth)
		
		// clear
		.define_method("ofClear",            wrap_ofClear(&ofClear))
		
		// colors
		.define_method("ofBackground",       wrap_ofBackground(&ofBackground))
		.define_method("ofBackgroundHex",    wrap_ofBackgroundHex(&ofBackgroundHex))
		.define_method("ofSetColor",         wrap_ofSetColor(&ofSetColor))
		.define_method("ofSetHexColor",      wrap_ofSetHexColor(&ofSetHexColor))
		
		// matrix stack manipulation
		.define_method("ofPushStyle",        &ofPushStyle)
		.define_method("ofPopStyle",         &ofPopStyle)
		.define_method("ofPushMatrix",       &ofPushMatrix)
		.define_method("ofPopMatrix",        &ofPopMatrix)
		
		// transforms
		.define_method("ofTranslate",      wrap_ofTranslate(&ofTranslate))
		.define_method("ofScale",          wrap_ofScale(&ofScale))
		
		.define_method("ofRotateX",        &ofRotateX)
		.define_method("ofRotateY",        &ofRotateY)
		.define_method("ofRotateZ",        &ofRotateZ)
		
		.define_method("ofRotate",        wrap_ofRotateAroundAxis(&ofRotate))
		
		
		.define_method("ofLoadIdentityMatrix",    &ofLoadIdentityMatrix)
		
		.define_method("ofLoadMatrix",        wrap_matrix_op(&ofLoadMatrix))
		.define_method("ofMultMatrix",        wrap_matrix_op(&ofMultMatrix))
		
		
		.define_method("ofSetMatrixMode",         &ofSetMatrixMode)
		.define_method("ofLoadViewMatrix",        &ofLoadViewMatrix)
		.define_method("ofMultViewMatrix",        &ofMultViewMatrix)
		.define_method("ofGetCurrentViewMatrix",  &ofGetCurrentViewMatrix)
	;
	
	// ------------------
	
	// NOTE: ofSetHexColor doesn't allow for alpha value. 
	// maybe define a custom version here that does use alpha?
	
	
	// ofDrawCurve
	// ofDrawBezier // <-- this one is pretty complicated. check it out. it's kinda cool.
	// TODO: find out what the difference / connection is between ofDrawCurve and ofDrawBezier
	
	return rb_mGraphics;
}
