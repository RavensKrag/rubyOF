#pragma once
#include "ofMain.h"

// must be a subclass of ofCamera to use render pipeline defined in ofGLProgrammableRenderer
// but I would rather just inherit from ofNode, as I think it makes more sense to have the code located here, instead of deferring to the renderer.
class ofxCamera : public ofNode {
public:
	ofxCamera();
	
	// mode switching
	bool getOrtho();
	void enableOrtho();
	void disableOrtho();
	
	void useOrthographic();
	void usePerspective();
	
	// core render callbacks
	void begin();
	void begin(const ofRectangle & viewport);
	void end();
		void begin_perspective(const ofRectangle & viewport);
		void end_perspective();
		void begin_ortho(const ofRectangle & viewport);
		void end_ortho();
	
	
	glm::mat4 getProjectionMatrix(const ofRectangle & viewport);
	glm::mat4 getProjectionMatrix(){
		return getProjectionMatrix(getViewport());
	}
	glm::mat4 getModelViewMatrix() const;
	
	glm::mat4 getModelViewProjectionMatrix(const ofRectangle & viewport);
	glm::mat4 getModelViewProjectionMatrix(){
		return getModelViewProjectionMatrix(getViewport());
	}
	
	
	
	
	// 
	// general properties
	// 
	
	void setVFlip(bool vflip);
	void setNearClip(float f);
	void setFarClip(float f);
	// void setLensOffset(const glm::vec2 & lensOffset);
	
	bool isVFlipped() const { return vFlip };
	float getNearClip() const { return mNearClip; };
	float getFarClip() const { return mFarClip; };
	// glm::vec2 getLensOffset() const { return lensOffset; };
	
	// 
	// perspective only
	// 
	
	void setupPerspective(bool vFlip = true, float fov = 60, float nearDist = 0, float farDist = 0, const glm::vec2 & lensOffset = glm::vec2(0.0f, 0.0f));
	
	void setFov(float f);
	void setAspectRatio(float aspectRatio);
	void setForceAspectRatio(bool forceAspectRatio);
	
	float getFov() const { return mFOV; };
	bool getForceAspectRatio() const {return mForceAspectRatio;};
	float getAspectRatio() const {return mAspectRatio; };
	
	// 
	// ortho only
	// 
	
	void setupOrthographic(bool vFlip = true, float scale = 1, float nearDist = 0, float farDist = 0);
	
	void setOrthoScale(float scale);
	
	float getOrthoScale();
	
	
	// 
	// coordinate space conversion
	// 
	
	glm::vec3 worldToScreen(glm::vec3 WorldXYZ, const ofRectangle & viewport) const;
	glm::vec3 worldToScreen(glm::vec3 WorldXYZ) const{
		return worldToScreen(WorldXYZ, getViewport());
	}
	
	glm::vec3 screenToWorld(glm::vec3 ScreenXYZ, const ofRectangle & viewport) const;
	glm::vec3 screenToWorld(glm::vec3 ScreenXYZ) const{
		return screenToWorld(ScreenXYZ, getViewport());
	}
	
	glm::vec3 worldToCamera(glm::vec3 WorldXYZ, const ofRectangle & viewport) const;
	glm::vec3 worldToCamera(glm::vec3 WorldXYZ) const{
		return worldToCamera(WorldXYZ, getViewport());
	}

	glm::vec3 cameraToWorld(glm::vec3 CameraXYZ, const ofRectangle & viewport) const;
	glm::vec3 cameraToWorld(glm::vec3 CameraXYZ) const{
		return cameraToWorld(CameraXYZ, getViewport());
	}
	
	
	// 
	// helper funcitons / utilities
	// 
	
	ofRectangle ofxCamera::getViewport() const{
		return getRenderer()->getCurrentViewport();
	}
	
	
	
	
	// 
	// ???
	// 
	
	
	
	void setupOffAxisViewPortal(const glm::vec3 & topLeft, const glm::vec3 & bottomLeft, const glm::vec3 & bottomRight);
	
	void enableOrtho();
    void disableOrtho();
    bool getOrtho() const;
	
	void calcClipPlanes(const ofRectangle & viewport);
	float getImagePlaneDistance(const ofRectangle & viewport) const;

	
	
	
private:
	// mode switch
	bool isOrtho;
	
	// all modes
	bool vFlip;
	glm::vec2 mLensOffset;
	float mNearClip;
	float mFarClip;
	
	// perspective mode only
	bool mForceAspectRatio;
	float mAspectRatio;
	float mFOV;
	
	// orthographic mode only
	float mOrthoScale;
};