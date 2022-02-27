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

inline glm::mat4
colors_to_mat4(const ofFloatColor &v1,
               const ofFloatColor &v2,
               const ofFloatColor &v3,
               const ofFloatColor &v4)
{
	return glm::mat4x4(v1.r, v2.r, v3.r, v4.r,
	                   v1.g, v2.g, v3.g, v4.g,
	                   v1.b, v2.b, v3.b, v4.b,
	                   v1.a, v2.a, v3.a, v4.a);
}

void
mat4_to_colors(const glm::mat4& mat,
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






EntityData::EntityData():
	mTransform(),
	mMaterial()
{
	mActive = false;  // Is this entry in the pool currently being used?
	mChanged = false; // Does this cached value need to be pushed to the ofPixels?
	mMeshIndex = 0;
}




int
EntityData::getMeshIndex() const{
	return mMeshIndex;
}

void
EntityData::setMeshIndex(int meshIndex){
	mMeshIndex = meshIndex;
	mChanged = true;
}









void
EntityData::copyMaterial(const EntityData& other){
	mMaterial.ambient = other.getAmbient();
	mMaterial.diffuse = other.getDiffuse();
	mMaterial.specular = other.getSpecular();
	mMaterial.emissive = other.getEmissive();
	mMaterial.alpha = other.getAlpha();
	
	mChanged = true;
}

ofFloatColor
EntityData::getAmbient() const{
	return mMaterial.ambient;
}

ofFloatColor
EntityData::getDiffuse() const{
	return mMaterial.diffuse;
}

ofFloatColor
EntityData::getSpecular() const{
	return mMaterial.specular;
}

ofFloatColor
EntityData::getEmissive() const{
	return mMaterial.emissive;
}

float
EntityData::getAlpha() const{
	return mMaterial.alpha;
}

void
EntityData::setAmbient(const ofFloatColor& value){
	mMaterial.ambient = value;
	mChanged = true;
}

void
EntityData::setDiffuse(const ofFloatColor& value){
	mMaterial.diffuse = value;
	mChanged = true;
}

void
EntityData::setSpecular(const ofFloatColor& value){
	mMaterial.specular = value;
	mChanged = true;
}

void
EntityData::setEmissive(const ofFloatColor& value){
	mMaterial.emissive = value;
	mChanged = true;
}

void
EntityData::setAlpha(float value){
	mMaterial.alpha = value;
	mChanged = true;
}


// move data from pixels into this MaterialProperites object
void
EntityData::loadMaterial(const ofFloatPixels::ConstPixels &scanline){
	int i = 0;
	for(auto itr = scanline.begin(); itr != scanline.end(); itr++){
		const ofFloatColor color = itr.getColor();
		
		if(i == 0){
			mMaterial.ambient = color;
		}
		if(i == 1){
			mMaterial.diffuse = color;
			mMaterial.alpha = color.a;
		}
		if(i == 2){
			mMaterial.specular = color;
		}
		if(i == 3){
			mMaterial.emissive = color;
		}
		
		i++;
	}
}

// write data from this MaterialComponent object into pixels
void
EntityData::updateMaterial(ofFloatPixels& pixels, int scanline_index, int x_start){
	int i=0;
	for(int j=x_start; j<mMaterial.num_pixels; j++){
		ofFloatColor color;
		
		if(i == 0){
			color = mMaterial.ambient;
		}
		if(i == 1){
			color = mMaterial.diffuse;
			color.a = mMaterial.alpha;
		}
		if(i == 2){
			color = mMaterial.specular;
		}
		if(i == 3){
			color = mMaterial.emissive;
		}
		
		
		pixels.setColor(j,scanline_index, color);
		i++;
	}
	

}













void
EntityData::copyTransform(const EntityData& other){
	mTransform.position    = other.getPosition();
	mTransform.orientation = other.getOrientation();
	mTransform.scale       = other.getScale();
	
	this->createMatrix();
	
	mChanged = true;
}

const glm::mat4&
EntityData::getTransformMatrix() const{
	return mTransform.local_transform;
}

glm::vec3
EntityData::getPosition() const{
	return mTransform.position;
}

glm::quat
EntityData::getOrientation() const{
	return mTransform.orientation;
}

glm::vec3
EntityData::getScale() const{
	return mTransform.scale;
}

void
EntityData::setTransformMatrix(const glm::mat4& mat){
	mTransform.local_transform = mat;
	decompose_matrix(mTransform.local_transform,
	                 mTransform.position, mTransform.orientation, mTransform.scale);
	mChanged = true;
}

void
EntityData::setPosition(const glm::vec3& value){
	mTransform.position = value;
	mChanged = true;
	this->createMatrix();
}

void
EntityData::setOrientation(const glm::quat& value){
	mTransform.orientation = value;
	mChanged = true;
	this->createMatrix();
}

void
EntityData::setScale(const glm::vec3& value){
	mTransform.scale = value;
	mChanged = true;
	this->createMatrix();
}

void
EntityData::createMatrix(){
	// based on openFrameworks/libs/openFrameworks/3d/ofNode.cpp:createMatrix()
	glm::mat4 mat = mTransform.local_transform;
	
	mat = glm::translate(glm::mat4(1.0), mTransform.position);
	mat = mat * glm::toMat4(mTransform.orientation);
	mat = glm::scale(mat, mTransform.scale);
	
	mTransform.local_transform = mat;
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
	
	this->setTransformMatrix( colors_to_mat4(c1, c2, c3, c4) );	
	
	
	int starting_index = 5;
	int num_pixels = mMaterial.num_pixels;
	int max_num_material_pixels = pixels.getWidth() - starting_index;
	
	if(num_pixels > max_num_material_pixels){
		ofLogError("EntityData") << "Too many pixels required to pack the material properties. Expected " << num_pixels << " pixels, but only found " << max_num_material_pixels << " pixels for material data in this image.";
		
		return false;
	}
	
	this->loadMaterial( pixels.getConstLine(scanline_index).getPixels(starting_index, num_pixels) );
	
	
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
		mat4_to_colors(this->getTransformMatrix(), &c1, &c2, &c3, &c4);
		
		pixels.setColor(1, scanline_index, c1);
		pixels.setColor(2, scanline_index, c2);
		pixels.setColor(3, scanline_index, c3);
		pixels.setColor(4, scanline_index, c4);
		
		
		int starting_index = 5;
		int num_pixels = mMaterial.num_pixels;
		int max_num_material_pixels = pixels.getWidth() - starting_index;
		
		if(num_pixels > max_num_material_pixels){
			ofLogError("EntityData") << "Too many pixels required to pack the material properties. Requsted " << num_pixels << " pixels, but only have space for " << max_num_material_pixels << " pixels in this image.";
			
			return false;
			// TODO: figure out some way to bail out of updating when there are not enough pixels
		}
		
		this->updateMaterial(pixels, scanline_index, starting_index);
		
		
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


EntityData*
EntityCache::getEntity(int index){
	return &(mStorage[index]);
}

// cache will mark an unused entry in the pool for use and return the index
int
EntityCache::createEntity(){
	
}

// mark a used entry in the pool as no longer being used
void EntityCache::destroyEntity(int index){
	
}

