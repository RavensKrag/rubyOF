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

void
ofxCamera::begin(){
	begin(getViewport());
}

void
ofxCamera::begin(const ofRectangle & viewport){
	// if(isOrtho){
	// 	begin_ortho(viewport);
	// }else{
	// 	begin_perspective(viewport);
	// }
	
	// ofGetCurrentRenderer()->bind(*this,viewport);
	
	auto renderer = ofGetCurrentRenderer();
	
	renderer->pushView();
	renderer->viewport(viewport);
	
	// renderer->setOrientation(matrixStack.getOrientation(),camera.isVFlipped());
	// ^ Can't access the matrix stack from outside of the GL renderer... not sure what to pass here
	//   Let's just pass the default orientation for now.
	//   This means we can't support orientation change with this camera, but that's ok.
	renderer->setOrientation(OF_ORIENTATION_DEFAULT, mVFlip);
	
	renderer->matrixMode(OF_MATRIX_PROJECTION);
	renderer->loadMatrix(getProjectionMatrix(viewport));
	
	renderer->matrixMode(OF_MATRIX_MODELVIEW);
	renderer->loadViewMatrix(getModelViewMatrix());
}

void
ofxCamera::end(){
	// if(isOrtho){
	// 	end_ortho();
	// }else{
	// 	end_perspective();
	// }
	
	// ofGetCurrentRenderer()->unbind(*this);
	
	auto renderer = ofGetCurrentRenderer();
	renderer->popView();
}


// // 
// // perspective camera rendering mode
// // 
// void ofxCamera::begin_perspective(const ofRectangle & viewport){
	
// }

// void ofxCamera::end_perspective(){
	
// }


// // 
// // orthographic camera rendering mode
// // 
// void ofxCamera::begin_ortho(const ofRectangle & viewport){
   
// }

// void ofxCamera::end_ortho(){
   
// }



//----------------------------------------
glm::mat4
ofxCamera::getProjectionMatrix(){
	return getProjectionMatrix(getViewport());
}

//----------------------------------------
glm::mat4
ofxCamera::getProjectionMatrix(const ofRectangle & viewport) {
	// autocalculate near/far clip planes if not set by user
	calcClipPlanes(viewport);
	
	if(isOrtho) {
		// NOTE: Current implementation does not support lens offset
		
		// use negative scaling to flip Blender's z axis
		// (not sure why it ends up being the second component, but w/e)
		glm::mat4 m5 = glm::scale(glm::mat4(1.0),
		                          glm::vec3(1, -1, 1));
		
		// NOTE: viewfac can be either width or height, whichever is greater
		float viewfac;
		if(viewport.width > viewport.height){
			viewfac = viewport.width;
		}else{
			viewfac = viewport.height;
		}
		
		// # TODO: viewfac should be based on the sensor fit
			// # src: blender-git/blender/source/blender/blenkernel/intern/camera.c
			// # inside the function BKE_camera_params_compute_viewplane() :
			// # 
			// # 
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
		
	}else{
		float aspect = mForceAspectRatio ? mAspectRatio : viewport.width/viewport.height;
		auto projection = glm::perspective(glm::radians(mFOV), aspect, mNearClip, mFarClip);
		projection = (glm::translate(glm::mat4(1.0), {-mLensOffset.x, -mLensOffset.y, 0.f})
						  * projection);
		return projection;
	}
}


//----------------------------------------
glm::mat4
ofxCamera::getModelViewMatrix() const {
	// TODO: only use position and orientation, but not scale
	return glm::inverse(getGlobalTransformMatrix());
}


//----------------------------------------
glm::mat4
ofxCamera::getModelViewProjectionMatrix(){
	return getModelViewProjectionMatrix(getViewport());
}

//----------------------------------------
glm::mat4
ofxCamera::getModelViewProjectionMatrix(const ofRectangle & viewport) {
	return getProjectionMatrix(viewport) * getModelViewMatrix();
}








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

//----------------------------------------
ofRectangle 
ofxCamera::getViewport() const{
	return getRenderer()->getCurrentViewport();
}

//----------------------------------------
shared_ptr<ofBaseRenderer>
ofxCamera::getRenderer() const{
	if(!mRenderer){
		return ofGetCurrentRenderer();
	}else{
		return mRenderer;
	}
}

//----------------------------------------
void
ofxCamera::setRenderer(std::shared_ptr<ofBaseRenderer> renderer){
	mRenderer = renderer;
}


