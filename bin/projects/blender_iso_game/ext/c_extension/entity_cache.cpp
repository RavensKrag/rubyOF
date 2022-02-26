#include "entity_cache.h"




// https://stackoverflow.com/questions/17918033/glm-decompose-mat4-into-translation-and-rotation
// answered 2021-07-09 @ 23:33
// by tuket
// 
// const glm::mat4& m    input parameter
// glm::vec3& pos        in / out parameter
// glm::quat& rot        in / out parameter
// glm::vec3& scale      in / out parameter
void decompose_matrix(const glm::mat4& m, glm::vec3& pos, glm::quat& rot, glm::vec3& scale)
{
    pos = m[3];
    for(int i = 0; i < 3; i++)
        scale[i] = glm::length(glm::vec3(m[i]));
    const glm::mat3 rotMtx(
        glm::vec3(m[0]) / scale[0],
        glm::vec3(m[1]) / scale[1],
        glm::vec3(m[2]) / scale[2]);
    rot = glm::quat_cast(rotMtx);
}

inline glm::mat4 colors_to_mat4(const ofFloatColor &v1,
                                const ofFloatColor &v2,
                                const ofFloatColor &v3,
                                const ofFloatColor &v4)
{
	return glm::mat4x4(v1.r, v2.r, v3.r, v4.r,
	                   v1.g, v2.g, v3.g, v4.g,
	                   v1.b, v2.b, v3.b, v4.b,
	                   v1.a, v2.a, v3.a, v4.a);
}

void mat4_to_colors(const glm::mat4& mat,
                    ofFloatColor *v1,
                    ofFloatColor *v2,
                    ofFloatColor *v3,
                    ofFloatColor *v4)
{
	v1->r = mat[0][0]; v1->g = mat[1][0]; v1->b = mat[2][0]; v1->a = mat[3][0];
	v2->r = mat[0][1]; v2->g = mat[1][1]; v2->b = mat[2][1]; v2->a = mat[3][1];
	v3->r = mat[0][2]; v3->g = mat[1][2]; v3->b = mat[2][2]; v3->a = mat[3][2];
	v4->r = mat[0][3]; v4->g = mat[1][3]; v4->b = mat[2][3]; v4->a = mat[3][3];
}





// MaterialProperties::MaterialProperties(){
// 	// NO-OP
//   (may want to use this to define default material?)
// }

// no explict copy constructor needed because we can just copy each and every member (default)

// Defining setters and getters instead of just using simple struct
// because this class needs to be wrapped up and accessed from Ruby
// as well as from c++

ofFloatColor
MaterialProperties::getAmbient() const{
	return mAmbient;
}

ofFloatColor
MaterialProperties::getDiffuse() const{
	return mDiffuse;
}

ofFloatColor
MaterialProperties::getSpecular() const{
	return mSpecular;
}

ofFloatColor
MaterialProperties::getEmissive() const{
	return mEmissive;
}

float
MaterialProperties::getAlpha(){
	return mAlpha;
}

void
MaterialProperties::setAmbient(const ofFloatColor& value){
	mAmbient = value;
}

void
MaterialProperties::setDiffuse(const ofFloatColor& value){
	mDiffuse = value;
}

void
MaterialProperties::setSpecular(const ofFloatColor& value){
	mSpecular = value;
}

void
MaterialProperties::setEmissive(const ofFloatColor& value){
	mEmissive = value;
}

void
MaterialProperties::setAlpha(float value){
	mAlpha = value;
}

// number of pixels needed to pack the data
int
MaterialProperties::getNumPixels() const{
	return 4;
}

// move data from pixels into this MaterialProperites object
void
MaterialProperties::load(const ofFloatPixels::ConstPixels &scanline){
	int i = 0;
	for(auto itr = scanline.begin(); itr != scanline.end(); itr++){
		const ofFloatColor color = itr.getColor();
		
		if(i == 0){
			mAmbient = color;
		}
		if(i == 1){
			mDiffuse = color;
			mAlpha = color.a;
		}
		if(i == 2){
			mSpecular = color;
		}
		if(i == 3){
			mEmissive = color;
		}
		
		i++;
	}
}

// write data from this MaterialProperties object into pixels
void
MaterialProperties::update(ofFloatPixels& pixels, int scanline_index, int x_start){
	int i=0;
	for(int j=x_start; j<this->getNumPixels(); j++){
		ofFloatColor color;
		
		if(i == 0){
			color = mAmbient;
		}
		if(i == 1){
			color = mDiffuse;
			color.a = mAlpha;
		}
		if(i == 2){
			color = mSpecular;
		}
		if(i == 3){
			color = mEmissive;
		}
		
		
		pixels.setColor(j,scanline_index, color);
		i++;
	}
	

}





EntityData::EntityData():
	mPosition(),
	mOrientation(),
	mScale(),
	mLocalTransform(),
	mMaterial()
{
	mActive = false;
	mChanged = false;
	mMeshIndex = 0;
}

int
EntityData::getMeshIndex() const{
	return mMeshIndex;
}

const glm::mat4&
EntityData::getTransform() const{
	return mLocalTransform;
}

glm::vec3&
EntityData::getPosition(){
	return mPosition;
}

glm::quat&
EntityData::getOrientation(){
	return mOrientation;
}

glm::vec3&
EntityData::getScale(){
	return mScale;
}

const MaterialProperties&
EntityData::getMaterial() const{
	return mMaterial;
}

void
EntityData::setMeshIndex(int meshIndex){
	mMeshIndex = meshIndex;
	mChanged = true;
}

void
EntityData::setTransform(const glm::mat4& mat){
	mLocalTransform = mat;
	decompose_matrix(mLocalTransform, mPosition, mOrientation, mScale);
	mChanged = true;
}

void
EntityData::setPosition(const glm::vec3& value){
	mPosition = value;
}

void
EntityData::setOrientation(const glm::quat& value){
	mOrientation = value;
}

void
EntityData::setScale(const glm::vec3& value){
	mScale = value;
}

void
EntityData::createMatrix(){
	// from openFrameworks/libs/openFrameworks/3d/ofNode.cpp
	mLocalTransform = glm::translate(glm::mat4(1.0), mPosition);
	mLocalTransform = mLocalTransform * glm::toMat4(mOrientation);
	mLocalTransform = glm::scale(mLocalTransform, mScale);
}

void
EntityData::setMaterial(const MaterialProperties& material){
	mMaterial = material; // should call copy constructor
	mChanged = true;
}

// attempt to load pixel data. return false on error.
bool
EntityData::load(const ofFloatPixels& pixels, int scanline_index){
	// check number of channels (expecting RGBA format)
	int channels = pixels.getNumChannels();
	if(channels != 4){
		ofLogError("EntityData") << "Expected image to have 4 channels (RGBA) but only found " << channels << " channels.";
		
		return false;
	}
	
	// 
	// load in the data
	// 
	
	float mesh_index = pixels.getColor(0, scanline_index).r;
	mMeshIndex = (int)mesh_index;
	// if no mesh is assigned, ignore the rest of the data in this line
	if(mMeshIndex == 0){
		mActive = false;
		return true;
	}else{
		mActive = true;
	}
	
	const ofFloatColor c1 = pixels.getColor(1, scanline_index);
	const ofFloatColor c2 = pixels.getColor(2, scanline_index);
	const ofFloatColor c3 = pixels.getColor(3, scanline_index);
	const ofFloatColor c4 = pixels.getColor(4, scanline_index);
	
	this->setTransform( colors_to_mat4(c1, c2, c3, c4) );	
	
	int starting_index = 5;
	int num_pixels = mMaterial.getNumPixels();
	int max_num_material_pixels = pixels.getWidth() - starting_index;
	
	if(num_pixels > max_num_material_pixels){
		ofLogError("EntityData") << "Too many pixels required to pack the material properties. Expected " << num_pixels << " pixels, but only found " << max_num_material_pixels << " pixels for material data in this image.";
		
		return false;
	}
	
	mMaterial.load( pixels.getConstLine(scanline_index).getPixels(starting_index, num_pixels) );
	
	
	return true; // if you do all operations, there was no error
}

// return true if data was updated, else false
bool
EntityData::update(ofFloatPixels& pixels, int scanline_index){
	if(mChanged){
		// 
		// write the data to the image
		// 
		ofFloatColor c;
		c = pixels.getColor(0, scanline_index);
			c.r = c.g = c.b = mMeshIndex;
		pixels.setColor(0, scanline_index, c);
		
		
		ofFloatColor c1, c2, c3, c4;
		mat4_to_colors(mLocalTransform, &c1, &c2, &c3, &c4);
		
		pixels.setColor(1, scanline_index, c1);
		pixels.setColor(2, scanline_index, c2);
		pixels.setColor(3, scanline_index, c3);
		pixels.setColor(4, scanline_index, c4);
		
		
		int starting_index = 5;
		int num_pixels = mMaterial.getNumPixels();
		int max_num_material_pixels = pixels.getWidth() - starting_index;
		
		if(num_pixels > max_num_material_pixels){
			ofLogError("EntityData") << "Too many pixels required to pack the material properties. Requsted " << num_pixels << " pixels, but only have space for " << max_num_material_pixels << " pixels in this image.";
			
			return false;
			// TODO: figure out some way to bail out of updating when there are not enough pixels
		}
		
		mMaterial.update(pixels, scanline_index, starting_index);
		
		
		mChanged = false;
		
		return true;
	}else{
		return false;
	}
}




EntityCache::EntityCache(int size){
	mStorage = new EntityData[size];
	mSize = size;
}

EntityCache::~EntityCache(){
	delete mStorage;
}

// read from pixel data into cache
// return false if there was an error with loading.
bool
EntityCache::load(const ofFloatPixels& pixels){
	// assume scanline index 0 is blank data,
	// thus pixels.getHeight() == n+1
	// where n is the number of entities
	// and n == mSize;
	
	
	// check to make sure the ofPixels object is the correct size for this cache
	if(pixels.getHeight() != mSize+1){
		ofLogError("EntityCache") << "ofPixels object was the wrong size for this cache object.";
		return false;
	}
	
	// if the size is correct, then copy over all data into cache
	for(int i=0; i<mSize; i++){
		int scanline_index = i+1;
		bool flag = mStorage[i].load(pixels, scanline_index);
		if(flag){
			ofLogError("EntityCache") <<  "Could not load entity data into cache. Problem parsing data on line " << scanline_index << "." << std::endl;
			return false;
		}
	}
	
	return true; // if you do all operations, there was no error
}

// write changed data to pixels
bool
EntityCache::update(ofFloatPixels& pixels){
	
	// check to make sure the ofPixels object is the correct size for this cache
	if(pixels.getHeight() != mSize+1){
		ofLogError("EntityCache") << "ofPixels object was the wrong size for this cache object.";
		return false;
	}
	
	// if the size is correct, then update all entries that need updating
	bool flag = false;
	for(int i=0; i<mSize; i++){
		int scanline_index = i+1;
		
		bool line_flag = mStorage[i].update(pixels, scanline_index);
		
		flag = flag || line_flag;
	}
	
	return flag; // notify of update if at least one entity was updated
}


// write ALL data to pixels
void
EntityCache::flush(ofFloatPixels& pixels){
	
}


EntityData&
EntityCache::getEntity(int index){
	return mStorage[index];
}

// // cache will mark an unused entry in the pool for use and return the index
// int EntityCache::createEntity(){
	
// }

// // mark a used entry in the pool as no longer being used
// void EntityCache::destroyEntity(int index){
	
// }

