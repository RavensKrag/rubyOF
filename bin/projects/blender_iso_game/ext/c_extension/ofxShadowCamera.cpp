//
//  ofxShadowCamera.cpp
//  emptyExample
//
//  Created by Ravenskrag, 7/3/2022
//  based on ofxShadowSimple by Nick Hardeman on 8/4/15.
//

#include "ofxShadowCamera.h"

//--------------------------------------------------------------
ofxShadowCamera::ofxShadowCamera() {
    // _width, _height, _depthBias, _intensity;
    _width.set( "u_shadowWidth", ofGetWidth());
    _height.set("u_shadowHeight", ofGetHeight() );
    _depthBias.set("u_shadowBias", 0.001, 0.00001, 0.01 );
    _intensity.set("u_shadowIntensity", 0.7, 0.0, 1.0 );
    _nearClip.set("ShadowNearClip", 1, 0, 1000 );
    _farClip.set("ShadowFarClip", 1000, 0, 5000 );
    
    mParams.setName("ofxShadowCamera");
    mParams.add( _depthBias );
    mParams.add( _intensity );
    mParams.add( _nearClip );
    mParams.add( _farClip );
    
    // setWidth( ofGetWidth() );
    // setHeight( ofGetHeight() );
    // setRange( _nearClip, _farClip );
    
    biasMatrix = ofMatrix4x4(
                           0.5, 0.0, 0.0, 0.0,
                           0.0, 0.5, 0.0, 0.0,
                           0.0, 0.0, 0.5, 0.0,
                           0.5, 0.5, 0.5, 1.0
                           );
    
    // setBias( 0.001 );
    // setIntensity( 0.7 );
    
    bTriedLoad = false;
}

//--------------------------------------------------------------
void ofxShadowCamera::load( string aVertPath, string aFragPath ) {
    bTriedLoad = true;
}

//--------------------------------------------------------------
void ofxShadowCamera::setRange( float nearClip, float farClip ) {
    lightCam.setNearClip( nearClip );
    lightCam.setFarClip( farClip );
    _nearClip = nearClip;
    _farClip = farClip;
}

//--------------------------------------------------------------
void ofxShadowCamera::setLightPosition( glm::vec3 aPos ) {
    lightCam.setPosition( aPos );
}

//--------------------------------------------------------------
void ofxShadowCamera::setLightOrientation(glm::quat rot ) {
    lightCam.setOrientation(rot);
}

//--------------------------------------------------------------
void ofxShadowCamera::setLightLookAt( glm::vec3 aPos, glm::vec3 upVector ) {
    lightCam.lookAt( aPos, upVector );
}

//--------------------------------------------------------------
void ofxShadowCamera::beginDepthPass() {
    
    if( lightCam.getNearClip() != _nearClip || lightCam.getFarClip() != _farClip ) {
        setRange(_nearClip, _farClip );
    }
    
    if( !shadowFbo.isAllocated() || shadowFbo.getWidth() != getWidth() || shadowFbo.getHeight() != getHeight() ) {
        allocateFbo();
    }
    
    glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
    
    shadowFbo.begin();
    ofClear(255);
    lightCam.begin();
    
    
    // glEnable( GL_CULL_FACE ); // cull front faces - this helps with artifacts and shadows with exponential shadow mapping
    // glCullFace( GL_BACK );
    
    
}

//--------------------------------------------------------------
void ofxShadowCamera::endDepthPass() {
    lightCam.end();
    shadowFbo.end();
    
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    
    // glCullFace( GL_BACK );
    // glDisable( GL_CULL_FACE );
}

//--------------------------------------------------------------
void ofxShadowCamera::beginRenderPass( ofCamera &aCam ) {    
    // shader.begin();
    // setShaderData( &shader, aCam, 3 );
}

//--------------------------------------------------------------
void ofxShadowCamera::endRenderPass() {
    // shader.end();
}

//--------------------------------------------------------------
void ofxShadowCamera::setShaderData( ofShader* ashader, ofCamera& aCam, int atexLoc ) {
    ashader->setUniformTexture( "u_shadowMap", shadowFbo.getDepthTexture(), atexLoc );
    
    ofMatrix4x4 inverseCameraMatrix = ofMatrix4x4::getInverseOf( aCam.getModelViewMatrix() );
    ofMatrix4x4 shadowTransMatrix = inverseCameraMatrix * lightCam.getModelViewMatrix() * lightCam.getProjectionMatrix() * biasMatrix;
    ashader->setUniformMatrix4f("u_shadowTransMatrix", shadowTransMatrix );
    
    ashader->setUniform1f(_width.getName(), getWidth() );
    ashader->setUniform1f(_height.getName(), getHeight() );
    ashader->setUniform1f(_depthBias.getName(), _depthBias );
    ashader->setUniform1f(_intensity.getName(), _intensity );
    ashader->setUniform3f("u_shadowLightPos", getLightCamera().getPosition() );
}

//--------------------------------------------------------------
void ofxShadowCamera::allocateFbo() {
    ofFbo::Settings settings;
    settings.width  = getWidth();
    settings.height = getHeight();
    settings.textureTarget = GL_TEXTURE_2D;
    settings.internalformat = GL_RGBA32F_ARB;
    settings.useDepth = true;
    settings.depthStencilAsTexture = true;
    settings.useStencil = true;
    // settings.depthStencilInternalFormat = GL_DEPTH_COMPONENT32;
    settings.maxFilter = GL_NEAREST;
    settings.minFilter = GL_NEAREST;

    
    shadowFbo.allocate( settings );
}

//--------------------------------------------------------------
void ofxShadowCamera::setWidth( float aWidth ) {
    int tw = aWidth;
    _width = tw;
}

//--------------------------------------------------------------
void ofxShadowCamera::setHeight( float aHeight ) {
    int th = aHeight;
    _height = th;
}

//--------------------------------------------------------------
float ofxShadowCamera::getWidth() {
    return _width;
}

//--------------------------------------------------------------
float ofxShadowCamera::getHeight() {
    return _height;
}

//--------------------------------------------------------------
void ofxShadowCamera::setBias( float aBias ) {
    _depthBias = aBias;
}

//--------------------------------------------------------------
float ofxShadowCamera::getBias() {
    return _depthBias;
}

//--------------------------------------------------------------
void ofxShadowCamera::setIntensity( float aIntensity ) {
    _intensity = aIntensity;
}

//--------------------------------------------------------------
float ofxShadowCamera::getIntensity() {
    return _intensity;
}

//--------------------------------------------------------------
glm::mat4 ofxShadowCamera::getLightSpaceMatrix() {
    return lightCam.getModelViewProjectionMatrix();
}

//--------------------------------------------------------------
ofTexture& ofxShadowCamera::getShadowMap() {
    return shadowFbo.getDepthTexture();
}





