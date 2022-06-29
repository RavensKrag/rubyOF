/*
 *  ofxDypnamicLight.cpp
 *  based on ofLight.cpp
 *  openFrameworksLib
 *
 *  original created by Memo Akten on 14/01/2011.
 *  Copyright 2011 MSA Visuals Ltd. All rights reserved.
 *
 */


#include "ofxDynamicLight.h"
#include "ofConstants.h"
#include "of3dUtils.h"
#include "ofGLBaseTypes.h"
#include "ofGLUtils.h"
#include <map>
#include <glm/gtc/quaternion.hpp>

using namespace std;

static ofFloatColor globalAmbient(0.2, 0.2, 0.2, 1.0);

// these are already declared by ofLight and so we don't need to declare them again

// //----------------------------------------
// void ofEnableLighting() {
// 	ofGetGLRenderer()->enableLighting();
// }

// //----------------------------------------
// void ofDisableLighting() {
// 	ofGetGLRenderer()->disableLighting();
// }

// //----------------------------------------
// bool ofGetLightingEnabled() {
// 	return ofGetGLRenderer()->getLightingEnabled();
// }

// //----------------------------------------
// void ofSetSmoothLighting(bool b) {
// 	ofGetGLRenderer()->setSmoothLighting(b);
// }

// //----------------------------------------
// void ofSetGlobalAmbientColor(const ofFloatColor& c) {
// 	ofGetGLRenderer()->setGlobalAmbientColor(c);
// 	globalAmbient = c;
// }

// const ofFloatColor & ofGetGlobalAmbientColor(){
// 	return globalAmbient;
// }


// 
// ofxDynamicLight is coupled with ofxDynamicMaterial in order to specify lighting properties.
// This class is based heavily on ofLight, but removes all fixed function pipeline code.
// In doing so, it is possible to create a cleaner interface where lighting data
// can be updated even when the light is disabled.
// (as we pass lighting data via uniforms, no global opengl state is modified)
// 

//----------------------------------------
vector<ofxDynamicLight::Data* > & ofxDynamicLightsData(){
	static vector<ofxDynamicLight::Data* > *lightsActive = new vector<ofxDynamicLight::Data* >();
   
   return *lightsActive;
}

ofxDynamicLight::Data::Data(){
	glIndex			= -1;
	isEnabled		= false;
	attenuation_constant = 0.000001;
	attenuation_linear = 0.000001;
	attenuation_quadratic = 0.000001;
	spotCutOff = 45;
	exponent = 16;
	width = 1;
	height = 1;
	lightType = OF_LIGHT_POINT;
}

ofxDynamicLight::Data::~Data(){
	// if(glIndex==-1) return;
   
}

//----------------------------------------
ofxDynamicLight::ofxDynamicLight()
:data(new Data){
   setDiffuseColor(ofColor(255,255,255));
   setSpecularColor(ofColor(255,255,255));
   setPointLight();
   
   // assume default attenuation factors //
   setAttenuation(1.f,0.f,0.f);
}

//----------------------------------------
void ofxDynamicLight::enable() {
   // std::cout << "try enable light" << std::endl;
   
   if(data->glIndex == -1){
      data->glIndex = ofxDynamicLightsData().size();
      ofxDynamicLightsData().push_back(data.get());
      
      // std::cout << "enable light" << data->glIndex << std::endl;
      
      data->isEnabled = true;
   }
}

//----------------------------------------
void ofxDynamicLight::disable() {
   if(data->glIndex == -1) return;
   
   // std::cout << "try disable light" << data->glIndex << std::endl;
   
   
   // v1 - c array style
   
   // int idx = -1;
   // for(size_t i=0; i < ofxDynamicLightsData().size(); i++ ){
   //    if(ofxDynamicLightsData()[i].lock()->glIndex == data->glIndex){
   //       idx = i;
   //    }
   // }
   // if(idx != -1){
   //    std::cout << "disable light" << data->glIndex << std::endl;
      
   //    data->isEnabled = false;
      
   //    ofxDynamicLightsData().erase( ofxDynamicLightsData().begin() + idx );  
   //    data->glIndex = -1;
   // }
   
   
   // v2 - using iterator
   for (auto it = ofxDynamicLightsData().begin(); it != ofxDynamicLightsData().end(); ) {
      if ((*it)->glIndex == data->glIndex) {
         // std::cout << "disable light" << data->glIndex << std::endl;
         
         it = ofxDynamicLightsData().erase(it);
         
         data->glIndex = -1;
         data->isEnabled = false;
      } else {
         it++;
      }
   }
   
}

//----------------------------------------
int ofxDynamicLight::getLightID() const{
	return data->glIndex;
}

//----------------------------------------
bool ofxDynamicLight::getIsEnabled() const {
	return data->isEnabled;
}

//----------------------------------------
void ofxDynamicLight::setDirectional() {
	data->lightType	= OF_LIGHT_DIRECTIONAL;
    
    onPositionChanged();
    onOrientationChanged();
}

//----------------------------------------
bool ofxDynamicLight::getIsDirectional() const {
	return data->lightType == OF_LIGHT_DIRECTIONAL;
}

//----------------------------------------
void ofxDynamicLight::setSpotlight(float spotCutOff, float exponent) {
	data->lightType		= OF_LIGHT_SPOT;
	setSpotlightCutOff( spotCutOff );
	setSpotConcentration( exponent );
    
    onPositionChanged();
    onOrientationChanged();
}

//----------------------------------------
bool ofxDynamicLight::getIsSpotlight() const{
	return data->lightType == OF_LIGHT_SPOT;
}

//----------------------------------------
void ofxDynamicLight::setSpotlightCutOff( float spotCutOff ) {
    data->spotCutOff = CLAMP(spotCutOff, 0, 90);
}

//----------------------------------------
float ofxDynamicLight::getSpotlightCutOff() const{
    if(!getIsSpotlight()) {
        ofLogWarning("ofxDynamicLight") << "getSpotlightCutOff(): light " << data->glIndex << " is not a spot light";
    }
    return data->spotCutOff;
}

//----------------------------------------
void ofxDynamicLight::setSpotConcentration( float exponent ) {
    data->exponent = CLAMP(exponent, 0, 128);
}

//----------------------------------------
float ofxDynamicLight::getSpotConcentration() const{
    if(!getIsSpotlight()) {
        ofLogWarning("ofxDynamicLight") << "getSpotConcentration(): light " << data->glIndex << " is not a spot light";
    }
    return data->exponent;
}

//----------------------------------------
void ofxDynamicLight::setPointLight() {
	data->lightType	= OF_LIGHT_POINT;
	
	onPositionChanged();
    onOrientationChanged();
}

//----------------------------------------
bool ofxDynamicLight::getIsPointLight() const{
	return data->lightType == OF_LIGHT_POINT;
}

//----------------------------------------
void ofxDynamicLight::setAttenuation( float constant, float linear, float quadratic ) {
    // falloff = 0 -> 1, 0 being least amount of fallof, 1.0 being most //
	data->attenuation_constant    = constant;
	data->attenuation_linear      = linear;
	data->attenuation_quadratic   = quadratic;
}

//----------------------------------------
float ofxDynamicLight::getAttenuationConstant() const{
    return data->attenuation_constant;
}

//----------------------------------------
float ofxDynamicLight::getAttenuationLinear() const{
    return data->attenuation_linear;
}

//----------------------------------------
float ofxDynamicLight::getAttenuationQuadratic() const{
    return data->attenuation_quadratic;
}

void ofxDynamicLight::setAreaLight(float width, float height){
	data->lightType = OF_LIGHT_AREA;
	data->width = width;
	data->height = height;
	
	onPositionChanged();
    onOrientationChanged();
}

bool ofxDynamicLight::getIsAreaLight() const{
	return data->lightType == OF_LIGHT_AREA;
}

//----------------------------------------
int ofxDynamicLight::getType() const{
	return data->lightType;
}

//----------------------------------------
void ofxDynamicLight::setDiffuseColor(const ofFloatColor& c) {
	data->diffuseColor = c;
}

//----------------------------------------
void ofxDynamicLight::setSpecularColor(const ofFloatColor& c) {
	data->specularColor = c;
}

//----------------------------------------
ofFloatColor ofxDynamicLight::getDiffuseColor() const {
	return data->diffuseColor;
}

//----------------------------------------
ofFloatColor ofxDynamicLight::getSpecularColor() const {
	return data->specularColor;
}


// ( callback for ofNode::draw() )
//----------------------------------------
void ofxDynamicLight::customDraw(const ofBaseRenderer * renderer) const{;
    if(getIsPointLight()) {
        renderer->drawSphere( 0,0,0, 10);
    } else if (getIsSpotlight()) {
        float coneHeight = (sin(data->spotCutOff*DEG_TO_RAD) * 30.f) + 1;
        float coneRadius = (cos(data->spotCutOff*DEG_TO_RAD) * 30.f) + 8;
		const_cast<ofBaseRenderer*>(renderer)->rotateDeg(-90,1,0,0);
		renderer->drawCone(0, -(coneHeight*.5), 0, coneHeight, coneRadius);
    } else  if (getIsAreaLight()) {
    	const_cast<ofBaseRenderer*>(renderer)->pushMatrix();
		renderer->drawPlane(data->width,data->height);
		const_cast<ofBaseRenderer*>(renderer)->popMatrix();
    }else{
        renderer->drawBox(10);
    }
    ofDrawAxis(20);
}




//-----------------------;-----------------
void ofxDynamicLight::onPositionChanged() {
   // std::cout << "light position updating" << std::endl;
   
	// if we are a positional light and not directional, update light position
	if(getIsSpotlight() || getIsPointLight() || getIsAreaLight()) {
		data->position = {getGlobalPosition().x, getGlobalPosition().y, getGlobalPosition().z, 1.f};
	}
}

//----------------------------------------
void ofxDynamicLight::onOrientationChanged() {
   // std::cout << "light orientation updating" << std::endl;
   
	if(getIsDirectional()) {
		// if we are a directional light and not positional, update light position (direction)
		glm::vec3 lookAtDir(glm::normalize(getGlobalOrientation() * glm::vec4(0,0,-1, 1)));
		data->position = {lookAtDir.x,lookAtDir.y,lookAtDir.z,0.f};
	}else if(getIsSpotlight() || getIsAreaLight()) {
		// determines the axis of the cone light
		glm::vec3 lookAtDir(glm::normalize(getGlobalOrientation() * glm::vec4(0,0,-1, 1)));
		data->direction = lookAtDir;
	}
	if(getIsAreaLight()){
		data->up = getUpDir();
		data->right = getXAxis();
	}
}
