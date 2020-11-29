#include "ofMain.h"
#include "Graphics.h"

using namespace Rice;


void ofEnableBlendMode__wrapper(int code){
	static const ofBlendMode BLEND_MODES[] = {
			OF_BLENDMODE_DISABLED,
			OF_BLENDMODE_ALPHA,
			OF_BLENDMODE_ADD,
			OF_BLENDMODE_MULTIPLY,
			OF_BLENDMODE_SCREEN,
			OF_BLENDMODE_SUBTRACT
	};
	
	ofEnableBlendMode(BLEND_MODES[code]);
}

void ofSetMatrixMode__wrapper(int code){
	// /home/ravenskrag/Desktop/gem_structure/ext/openFrameworks/libs/openFrameworks/graphics/ofGraphicsConstants.h:118
	// enum ofMatrixMode {OF_MATRIX_MODELVIEW=0, OF_MATRIX_PROJECTION, OF_MATRIX_TEXTURE};
	
	static const ofMatrixMode MATRIX_MODES[] = {
			OF_MATRIX_MODELVIEW,
			OF_MATRIX_PROJECTION,
			OF_MATRIX_TEXTURE,
	};
	
	ofSetMatrixMode(MATRIX_MODES[code]);
}

Rice::Module Init_rubyOF_graphics(Rice::Module rb_mRubyOF)
{
	// --- Bind the core types first, and then the interesting methods that use them.
	Data_Type<ofMatrixMode> rb_cMatrixMode = 
		define_class_under<ofMatrixMode>(rb_mRubyOF, "MatrixMode");
	
	
	
	Data_Type<ofMatrix4x4> rb_cMatrix4x4 = 
		define_class_under<ofMatrix4x4>(rb_mRubyOF,  "Matrix4x4");
	
	rb_cMatrix4x4
		.define_constructor(Constructor<ofMatrix4x4>())
		.define_method("set",			
         static_cast< void (ofMatrix4x4::*)
         (const float *const ptr)
         >(&ofMatrix4x4::set)
		)
	;
	
		// wrap #set to bind a series of floats to your matrix (it's overloaded)
	
	
	
	
	// --- Ok, time to bind some useful stuff.
	Module rb_mGraphics = define_module_under(rb_mRubyOF, "Graphics");
	// ------------------
	// global oF functions
	// ------------------
	
	
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
		
		
		
		// 
		// draw 3D primitives
		// 
		
		.define_method("ofDrawBox",
			static_cast< void (*)
			(
				float x, float y, float z, float size
			)
			>(&ofDrawBox)
		)
		.define_method("ofDrawSphere",
			static_cast< void (*)
			(
				float x, float y, float z, float radius
			)
			>(&ofDrawSphere)
		)
		
		
		// 
		// parameters for 3D primitives
		// 
		
		.define_method("ofSetSphereResolution",  &ofSetSphereResolution)
		
		
		
		
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
		
		
		
		
		// OpenGL render modes and lighting controls
		.define_method("ofEnableBlendMode",  &ofEnableBlendMode__wrapper)
		.define_method("ofDisableBlendMode", &ofDisableBlendMode)
		
		.define_method("ofEnableDepthTest",  &ofEnableDepthTest)
		.define_method("ofDisableDepthTest", &ofDisableDepthTest)
		
		.define_method("ofEnableLighting",  &ofEnableLighting)
		.define_method("ofDisableLighting", &ofDisableLighting)
		
		.define_method("ofGetLightingEnabled", &ofGetLightingEnabled)
		
		.define_method("ofSetSmoothLighting",  &ofSetSmoothLighting)
		
		
		
		
		
		
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
		.define_method(
			"ofPushView",
			&ofPushView
		)
		.define_method(
			"ofPopView",
			&ofPopView
		)
		
		.define_method(
			"ofViewport",
			static_cast< void (*)
			(float x, float y, float width, float height, bool invertY)
			>(&ofViewport)
		)
		.define_method(
			"ofGetCurrentViewport",
			static_cast< ofRectangle (*)
			(void)
			>(&ofGetCurrentViewport)
		)
		.define_method(
			"ofSetupScreenOrtho",
			static_cast< void (*)
			(float width, float height, float nearDist, float farDist)
			>(&ofSetupScreenOrtho),
			(
				
				Arg("width")    = -1,
				Arg("height")   = -1,
				Arg("nearDist") = -1,
				Arg("farDist")  = 1
			)
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
		
		.define_method("ofLoadMatrix",
         static_cast< void (*)
         (const glm::mat4 & m)
         >(&ofLoadMatrix)
      )
      .define_method("ofMultMatrix",
         static_cast< void (*)
         (const glm::mat4 & m)
         >(&ofMultMatrix)
      )
		// NOTE: other interface is not multiplication by scalar, it's a pointer to a 4x4 matrix (assuming the first element of a nested array or something? better to just use the provided types.)
		
		
		.define_method(
			"ofSetMatrixMode",  &ofSetMatrixMode__wrapper)
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
