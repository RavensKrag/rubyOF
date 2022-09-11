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
    
    void setSize( float width, float height );
    void setWidth( float aWidth );
    void setHeight( float aHeight );
    float getWidth();
    float getHeight();
    
    void setRange( float nearClip, float farClip );
    void setPosition( glm::vec3 aPos );
    void setOrientation(glm::quat rot );
    void lookAt( glm::vec3 aPos, glm::vec3 upVector = glm::vec3(0, 1, 0) );
    
    void setAngle(float angle_deg);
    
    void enableOrtho();
    void disableOrtho();
    
    void beginDepthPass();
    void endDepthPass();
    
    void beginRenderPass( ofCamera& aCam );
    void endRenderPass();
    
    void setShaderData( ofShader* ashader, ofCamera& aCam, int atexLoc=2 );
    
    // bias to reduce shadow acne //
    void setBias( float aBias );
    float getBias();
    
    // intensity of the shadows //
    void setIntensity( float aIntensity );
    float getIntensity();
    
    ofFbo& getFbo() { return shadowFbo; }
    ofCamera& getLightCamera() { return lightCam; }
    ofParameterGroup& getParams() { return mParams; }
    
    
    glm::mat4 getLightSpaceMatrix();
    ofTexture& getShadowMap();
    
protected:
    
    string fragShaderStr, vertShaderStr;
    
    ofMatrix4x4 biasMatrix;
    
    void allocateFbo();
    
    ofParameterGroup mParams;
    ofParameter<float> _width, _height, _depthBias, _intensity;
    ofParameter<float> _nearClip, _farClip;
    
    ofFbo shadowFbo;
    ofCamera lightCam;
};
