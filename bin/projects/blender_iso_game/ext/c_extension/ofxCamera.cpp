#include "ofxCamera.h"
// based on code from ofCamera

ofxCamera::ofxCamera(){
	// mode switch
	isOrtho = false;
	
	// all modes
	mVFlip = false;
	mLensOffset = glm::vec2(0.0f, 0.0f);
	mNearClip = 0;
	mFarClip = 0;
	
	// perspective mode only
	mForceAspectRatio = false;
	mAspectRatio = 4.0f / 3.0f;
	mFOV = 60;
	
	// orthographic mode only
	mOrthoScale = 1;
}

//----------------------------------------

bool
ofxCamera::getOrtho(){
	return isOrtho;
}

void
ofxCamera::enableOrtho(){
	isOrtho = true;
}

void
ofxCamera::disableOrtho(){
	isOrtho = false;
}

//----------------------------------------
// 
// Basic API
// 

void
ofxCamera::begin(){
	begin(ofGetCurrentViewport());
}

void
ofxCamera::begin(const ofRectangle & viewport){
	// ofGetCurrentRenderer()->bind(*this,viewport);
	
	auto renderer = ofGetCurrentRenderer();
	
	renderer->pushView();
	formatViewport(renderer, viewport);
	
	renderer->matrixMode(OF_MATRIX_PROJECTION);
	renderer->loadMatrix(getProjectionMatrix(viewport));
	
	renderer->matrixMode(OF_MATRIX_MODELVIEW);
	renderer->loadViewMatrix(getModelViewMatrix());
}

void
ofxCamera::end(){
	// ofGetCurrentRenderer()->unbind(*this);
	
	auto renderer = ofGetCurrentRenderer();
	renderer->popView();
}


//----------------------------------------
void
ofxCamera::formatViewport(std::shared_ptr<ofBaseRenderer> renderer, const ofRectangle & viewport){
	if(isOrtho){
		ortho_formatViewport(renderer, viewport);
	}else{
		persp_formatViewport(renderer, viewport);
	}
}

//----------------------------------------
glm::mat4
ofxCamera::getProjectionMatrix(){
	return getProjectionMatrix(ofGetCurrentViewport());
}

//----------------------------------------
glm::mat4
ofxCamera::getProjectionMatrix(const ofRectangle & viewport) {
	if(isOrtho){
		return ortho_getProjectionMatrix(viewport);
	}else{
		return persp_getProjectionMatrix(viewport);
	}
	
}

//----------------------------------------
glm::mat4
ofxCamera::getModelViewMatrix() const {
	if(isOrtho){
		return ortho_getModelViewMatrix();
	}else{
		return persp_getModelViewMatrix();
	}
}

//----------------------------------------
glm::mat4
ofxCamera::getModelViewProjectionMatrix(){
	return getModelViewProjectionMatrix(ofGetCurrentViewport());
}

//----------------------------------------
glm::mat4
ofxCamera::getModelViewProjectionMatrix(const ofRectangle & viewport) {
	return getProjectionMatrix(viewport) * getModelViewMatrix();
}




//----------------------------------------
// 
// Perspective camera rendering logic
// 

void
ofxCamera::persp_formatViewport(std::shared_ptr<ofBaseRenderer> renderer, const ofRectangle & vp){
	renderer->viewport(vp.x, vp.y, vp.width, vp.height, renderer->isVFlipped());
	
	// renderer->setOrientation(matrixStack.getOrientation(),camera.isVFlipped());
	// ^ Can't access the matrix stack from outside of the GL renderer... not sure what to pass here
	//   Let's just pass the default orientation for now.
	//   This means we can't support orientation change with this camera, but that's ok.
	renderer->setOrientation(OF_ORIENTATION_DEFAULT, mVFlip);
}

glm::mat4
ofxCamera::persp_getProjectionMatrix(const ofRectangle & viewport){
	// autocalculate near/far clip planes if not set by user
	// calcClipPlanes(viewport);
	
	float aspect = mForceAspectRatio ? mAspectRatio : viewport.width/viewport.height;
	auto projection = glm::perspective(glm::radians(mFOV), aspect, mNearClip, mFarClip);
	projection = (glm::translate(glm::mat4(1.0), {-mLensOffset.x, -mLensOffset.y, 0.f})
						* projection);
	return projection;
}

glm::mat4
ofxCamera::persp_getModelViewMatrix() const{
	return glm::inverse(getGlobalTransformMatrix());
}


//----------------------------------------
// 
// Orthographic camera rendering logic
// 

void
ofxCamera::ortho_formatViewport(std::shared_ptr<ofBaseRenderer> renderer, const ofRectangle & vp){
	renderer->viewport(vp.x, vp.y, vp.width, vp.height, false);
	renderer->setOrientation(OF_ORIENTATION_DEFAULT, true);
}

glm::mat4
ofxCamera::ortho_getProjectionMatrix(const ofRectangle & viewport){
	// NOTE: Current implementation does not support lens offset
	
	// use negative scaling to flip Blender's z axis
	// (not sure why it ends up being the second component, but w/e)
	glm::mat4 m5 = glm::scale(glm::mat4(1.0),
									glm::vec3(1, -1, 1));
	
	// NOTE: viewfac can be either width or height, whichever is greater
	float viewfac = ((viewport.width > viewport.height) ? viewport.width : viewport.height);
	
	// # TODO: viewfac should be based on the sensor fit
	// # src: blender-git/blender/source/blender/blenkernel/intern/camera.c
	// # inside the function BKE_camera_params_compute_viewplane() :
		// # if (sensor_fit == CAMERA_SENSOR_FIT_HOR) {
		// #   viewfac = winx;
		// # }
		// # else {
		// #   viewfac = params->ycor * winy;
		// # } 
	
	glm::mat4 projectionMat = glm::ortho(
		- viewport.width/2 * mOrthoScale / viewfac,
		+ viewport.width/2 * mOrthoScale / viewfac,
		- viewport.height/2 * mOrthoScale / viewfac,
		+ viewport.height/2 * mOrthoScale / viewfac,
		mNearClip,
		mFarClip
	);
	
	return projectionMat * m5;
}

glm::mat4
ofxCamera::ortho_getModelViewMatrix() const{
	// NOTE: for orthographic projection, only use position and orientation, but not scale
	glm::mat4 m1 = glm::translate(glm::mat4(1.0), this->getPosition());
	glm::mat4 m2 = glm::toMat4(this->getOrientationQuat());
	auto cameraTransform = m1 * m2;
	return glm::inverse(cameraTransform);
}





// 
// general properties
// 

void
ofxCamera::setVFlip(bool vflip){
	mVFlip = vflip;
}

void
ofxCamera::setNearClip(float f){
	mNearClip = f;
}

void
ofxCamera::setFarClip(float f){
	mFarClip = f;
}

// void setLensOffset(const glm::vec2 & lensOffset);



// 
// perspective only
// 

void
ofxCamera::setupPerspective(bool vFlip, float fov, float nearDist, float farDist)
{
	setVFlip(vFlip);
	setFov(fov);
	setNearClip(nearDist);
	setFarClip(farDist);
}

void
ofxCamera::setFov(float f){
	mFOV = f;
}

void
ofxCamera::setAspectRatio(float aspectRatio){
	mAspectRatio = aspectRatio;
}

void
ofxCamera::setForceAspectRatio(bool forceAspectRatio){
	mForceAspectRatio = forceAspectRatio;
}



// 
// ortho only
// 

void
ofxCamera::setupOrthographic(bool vFlip, float scale, float nearDist, float farDist){
	setVFlip(vFlip);
	setOrthoScale(scale);
	setNearClip(nearDist);
	setFarClip(farDist);
}

void
ofxCamera::setOrthoScale(float scale){
	mOrthoScale = scale;
}



// 
// coordinate space conversion
// 

glm::vec3
ofxCamera::worldToScreen(glm::vec3 WorldXYZ, const ofRectangle & viewport){
	auto CameraXYZ = worldToCamera(WorldXYZ, viewport);
	
	glm::vec3 ScreenXYZ;
	ScreenXYZ.x = (CameraXYZ.x + 1.0f) / 2.0f * viewport.width + viewport.x;
	ScreenXYZ.y = (1.0f - CameraXYZ.y) / 2.0f * viewport.height + viewport.y;
	ScreenXYZ.z = CameraXYZ.z;
	
	return ScreenXYZ;
}

glm::vec3
ofxCamera::screenToWorld(glm::vec3 ScreenXYZ, const ofRectangle & viewport){
	//convert from screen to camera
	glm::vec3 CameraXYZ;
	CameraXYZ.x = 2.0f * (ScreenXYZ.x - viewport.x) / viewport.width - 1.0f;
	CameraXYZ.y = 1.0f - 2.0f *(ScreenXYZ.y - viewport.y) / viewport.height;
	CameraXYZ.z = ScreenXYZ.z;
	
	return cameraToWorld(CameraXYZ, viewport);
}

glm::vec3
ofxCamera::worldToCamera(glm::vec3 WorldXYZ, const ofRectangle & viewport){
	auto MVPmatrix = getModelViewProjectionMatrix(viewport);
	if(mVFlip){
		MVPmatrix = glm::scale(glm::mat4(1.0), glm::vec3(1.f,-1.f,1.f)) * MVPmatrix;
	}
	auto camera = MVPmatrix * glm::vec4(WorldXYZ, 1.0);
	return glm::vec3(camera) / camera.w;
}

glm::vec3
ofxCamera::cameraToWorld(glm::vec3 CameraXYZ, const ofRectangle & viewport){
	auto MVPmatrix = getModelViewProjectionMatrix(viewport);
	if(mVFlip){
		MVPmatrix = glm::scale(glm::mat4(1.0), glm::vec3(1.f,-1.f,1.f)) * MVPmatrix;
	}
	auto world = glm::inverse(MVPmatrix) * glm::vec4(CameraXYZ, 1.0);
	return glm::vec3(world) / world.w;
}



glm::vec3
ofxCamera::worldToScreen(glm::vec3 WorldXYZ){
	return worldToScreen(WorldXYZ, ofGetCurrentViewport());
}

glm::vec3
ofxCamera::screenToWorld(glm::vec3 ScreenXYZ){
	return screenToWorld(ScreenXYZ, ofGetCurrentViewport());
}

glm::vec3
ofxCamera::worldToCamera(glm::vec3 WorldXYZ){
	return worldToCamera(WorldXYZ, ofGetCurrentViewport());
}

glm::vec3
ofxCamera::cameraToWorld(glm::vec3 CameraXYZ){
	return cameraToWorld(CameraXYZ, ofGetCurrentViewport());
}




// 
// helper funcitons / utilities
// 

//----------------------------------------
void
ofxCamera::calcClipPlanes(const ofRectangle & viewport) {
	// autocalculate near/far clip planes if not set by user
	if(mNearClip == 0 || mFarClip == 0) {
		float dist = getImagePlaneDistance(viewport);
		mNearClip = (mNearClip == 0) ? dist / 100.0f : mNearClip;
		mFarClip = (mFarClip == 0) ? dist * 10.0f : mFarClip;
	}
}

//----------------------------------------
float
ofxCamera::getImagePlaneDistance(const ofRectangle & viewport) const {
	return viewport.height / (2.0f * tanf(PI * mFOV / 360.0f));
}
