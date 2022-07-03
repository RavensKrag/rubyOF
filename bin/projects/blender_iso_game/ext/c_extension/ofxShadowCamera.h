//
//  ofxShadowCamera.h
//  emptyExample
//
//  Created by Ravenskrag, 7/3/2022
//  based on ofxShadowSimple by Nick Hardeman on 8/4/15.
//

#pragma once
#include "ofMain.h"

#define STRINGIFY(x) #x

class ofxShadowCamera {
public:
    
    ofxShadowCamera();
    
    void load( string aVertPath, string aFragPath );
    void setRange( float nearClip, float farClip );
    void setLightPosition( glm::vec3 aPos );
    void setLightOrientation(glm::quat rot );
    void setLightLookAt( glm::vec3 aPos, glm::vec3 upVector = glm::vec3(0, 1, 0) );
    
    void beginDepthPass( bool aBWithCam = true );
    void endDepthPass( bool aBWithCam = true );
    
    void beginRenderPass( ofCamera& aCam );
    void endRenderPass();
    void setShaderData( ofShader* ashader, ofCamera& aCam, int atexLoc=2 );
    
    void setWidth( float aWidth );
    void setHeight( float aHeight );
    float getWidth();
    float getHeight();
    
    // bias to reduce shadow acne //
    void setBias( float aBias );
    float getBias();
    
    // intensity of the shadows //
    void setIntensity( float aIntensity );
    float getIntensity();
    
    ofFbo& getFbo() { return shadowFbo; }
    ofCamera& getLightCamera() { return lightCam; }
    ofMatrix4x4 getShadowTransMatrix( ofCamera& acam );
    ofShader& getShader() { return shader; }
    ofParameterGroup& getParams() { return mParams; }
    
protected:
    
    string fragShaderStr, vertShaderStr;
    
    ofMatrix4x4 biasMatrix;
    
    void allocateFbo();
    
    bool bTriedLoad = false;
    
    ofParameterGroup mParams;
    ofParameter<float> _width, _height, _depthBias, _intensity;
    ofParameter<float> _nearClip, _farClip;
    
    ofFbo shadowFbo;
    ofCamera lightCam;
    ofShader shader;
};
