#include "ofMain.h"
#include "Graphics.h"

using namespace Rice;

Rice::Module Init_rubyOF_graphics(Rice::Module rb_mRubyOF)
{
	// --- Bind the core types first, and then the interesting methods that use them.
	Data_Type<ofMatrixMode> rb_cMatrixMode = 
		define_class_under<ofMatrixMode>(rb_mRubyOF, "MatrixMode");
	
	Data_Type<ofMatrix4x4> rb_cMatrix4x4 = 
		define_class_under<ofMatrix4x4>(rb_mRubyOF,  "Matrix4x4");
		
		// wrap #set to bind a series of floats to your matrix (it's overloaded)
	
	Data_Type<ofQuaternion> rb_cQuaternion = 
		define_class_under<ofQuaternion>(rb_mRubyOF, "Quaternion");
	
	// Vec3f is exactly the same as ofPoint. If you try to bind both,
	// Rice gets mad, and you get a runtime error.
	
	// Data_Type<ofVec3f> rb_cVec3f = 
	// 	define_class_under<ofVec3f>(rb_mRubyOF,  "Vec3f");
	
	Data_Type<ofVec4f> rb_cVec4f = 
		define_class_under<ofVec4f>(rb_mRubyOF,  "Vec4f");
	
	
	
	// --- Ok, time to bind some useful stuff.
	Module rb_mGraphics = define_module_under(rb_mRubyOF, "Graphics");
	// ------------------
	// global oF functions
	// ------------------
	
	typedef void (*wrap_matrix_op)(const glm::mat4 & m);
	
	rb_mGraphics
		// bitmap string
		.define_method("ofDrawBitmapString",
			static_cast< void (*)
			(const std::string& textString, float x, float y, float z)
			>(&ofDrawBitmapString)
		)
		
		// draw primatives
		.define_method("ofDrawRectangle",
			static_cast< void (*)
			(float x,float y,float z,float w,float h)
			>(&ofDrawRectangle)
		)
		.define_method("ofDrawCircle",
			static_cast< void (*)
			(float x, float y, float z, float radius)
			>(&ofDrawCircle)
		)
		.define_method("ofDrawEllipse",
			static_cast< void (*)
			(float x, float y, float z, float width, float height)
			>(&ofDrawEllipse)
		)
		.define_method("ofDrawTriangle",
			static_cast< void (*)
			(
				float x1,float y1,float z1,
				float x2,float y2,float z2,
				float x3, float y3,float z3
			)
			>(&ofDrawTriangle)
		)
		.define_method("ofDrawLine",
			static_cast< void (*)
			(float x1,float y1,float z1,float x2,float y2,float z2)
			>(&ofDrawLine)
		)
		.define_method("ofDrawRectRounded",
			static_cast< void (*)
			(
				float x, float y, float z,
				float w, float h,
				float topLeftRadius,
				float topRightRadius,
				float bottomRightRadius,
				float bottomLeftRadius
			)
			>(&ofDrawRectRounded)
		)
		
		// turn filling of primative shapes on / off
		// (used to draw outlines)
		.define_method(
			"ofFill",
			&ofFill
		)
		.define_method(
			"ofNoFill",
			&ofNoFill
		)
		
		// alter line weight
		.define_method("ofSetLineWidth",
			&ofSetLineWidth // (float lineWidth)
		)
		
		// clear
		.define_method("ofClear",
			static_cast< void (*)
			(float r, float g, float b, float a)
			>(&ofClear)
		)
		// NOTE: clear requires floats, while "ofBackground" takes int? Looks weird, maybe should report?
		
		// colors
		.define_method("ofBackground",
			static_cast< void (*)
			(int r, int g, int b, int a)
			>(&ofBackground)
		)
		.define_method("ofBackgroundHex",
			static_cast< void (*)
			(int hexColor, int alpha)
			>(&ofBackgroundHex)
		)
		.define_method("ofSetColor",
			static_cast< void (*)
			(const ofColor & color)
			>(&ofSetColor)
		)
		.define_method("ofSetHexColor",
			static_cast< void (*)
			(int hexColor)
			>(&ofSetHexColor)
		)
		
		// matrix stack manipulation
		.define_method(
			"ofPushStyle",
			&ofPushStyle
		)
		.define_method(
			"ofPopStyle",
			&ofPopStyle
		)
		.define_method(
			"ofPushMatrix",
			&ofPushMatrix
		)
		.define_method(
			"ofPopMatrix",
			&ofPopMatrix
		)
		
		
		
		// transforms
		.define_method(
			"ofTranslate",
			
			static_cast< void (*)
			(float x, float y, float z)
			>(&ofTranslate)
		)
		.define_method(
			"ofScale",
			
			static_cast< void (*)
			(float xAmnt, float yAmnt, float zAmnt)
			>(&ofScale)
		)
		
		.define_method(
			"ofRotateX",
			&ofRotateX // (float degrees)
		)
		.define_method(
			"ofRotateY",
			&ofRotateY // (float degrees)
		)
		.define_method(
			"ofRotateZ",
			&ofRotateZ // (float degrees)
		)
		// DEPRECIATED: ofRotateX / ofRotateY / ofRotateZ
		//              Must now specify degrees or radians
		//              e.g. ofRotateYDeg or ofRotateYRad
		
		.define_method(
			"ofRotate",
			
			// rotate around axis specified by vector
			// (funciton is overloaded: other interfaces exist)
			static_cast< void (*)
			(float degrees, float vecX, float vecY, float vecZ)
			>(&ofRotate)
		)
		// DEPRECIATED: ofRotate
		//              Use ofRotateDeg or ofRotateRad
		
		
		.define_method(
			"ofLoadIdentityMatrix",
			&ofLoadIdentityMatrix // ()
		)
		
		.define_method(
			"ofLoadMatrix",
			wrap_matrix_op(&ofLoadMatrix)
		)
		.define_method(
			"ofMultMatrix",
			wrap_matrix_op(&ofMultMatrix)
		)
		// NOTE: other interface is not multiplication by scalar, it's a pointer to a 4x4 matrix (assuming the first element of a nested array or something? better to just use the provided types.)
		
		
		.define_method(
			"ofSetMatrixMode",
			&ofSetMatrixMode // (ofMatrixMode matrixMode)
		)
		.define_method(
			"ofLoadViewMatrix",
			&ofLoadViewMatrix // (const glm::mat4 & m)
		)
		.define_method(
			"ofMultViewMatrix",
			&ofMultViewMatrix // (const glm::mat4 & m)
		)
		.define_method(
			"ofGetCurrentViewMatrix",
			&ofGetCurrentViewMatrix // ()
		)
	;
	
	// ------------------
	
	// NOTE: ofSetHexColor doesn't allow for alpha value. 
	// maybe define a custom version here that does use alpha?
	
	
	// ofDrawCurve
	// ofDrawBezier // <-- this one is pretty complicated. check it out. it's kinda cool.
	// TODO: find out what the difference / connection is between ofDrawCurve and ofDrawBezier
	
	return rb_mGraphics;
}
