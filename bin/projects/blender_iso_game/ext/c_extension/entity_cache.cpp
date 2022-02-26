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

inline glm::mat4 get_entity_transform(const ofFloatPixels &pixels, const int i){
	// glm::mat4 mat(1);
	
	// pull colors out of image on CPU side
	// similar to how the shader pulls data out on the GPU side
	
	ofFloatColor v1 = pixels.getColor(1, i);
	ofFloatColor v2 = pixels.getColor(2, i);
	ofFloatColor v3 = pixels.getColor(3, i);
	ofFloatColor v4 = pixels.getColor(4, i);

	glm::mat4x4 mat(v1.r, v2.r, v3.r, v4.r,
	                v1.g, v2.g, v3.g, v4.g,
	                v1.b, v2.b, v3.b, v4.b,
	                v1.a, v2.a, v3.a, v4.a);
	
	
	return mat;
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





// MaterialProperties::MaterialProperties(){
// 	// NO-OP
//   (may want to use this to define default material?)
// }

// no explict copy constructor needed because we can just copy each and every member (default)

// Defining setters and getters instead of just using simple struct
// because this class needs to be wrapped up and accessed from Ruby
// as well as from c++

ofFloatColor MaterialProperties::getAmbient() const{
	return mAmbient;
}

ofFloatColor MaterialProperties::getDiffuse() const{
	return mDiffuse;
}

ofFloatColor MaterialProperties::getSpecular() const{
	return mSpecular;
}

ofFloatColor MaterialProperties::getEmissive() const{
	return mEmissive;
}

float MaterialProperties::getAlpha(){
	return mAlpha;
}

void MaterialProperties::setAmbient(const ofFloatColor& value){
	mAmbient = value;
}

void MaterialProperties::setDiffuse(const ofFloatColor& value){
	mDiffuse = value;
}

void MaterialProperties::setSpecular(const ofFloatColor& value){
	mSpecular = value;
}

void MaterialProperties::setEmissive(const ofFloatColor& value){
	mEmissive = value;
}

void MaterialProperties::setAlpha(float value){
	mAlpha = value;
}

// number of pixels needed to pack the data
int MaterialProperties::getNumPixels() const{
	return 4;
}

void MaterialProperties::load(const ofFloatPixels::ConstPixels &scanline){
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





EntityData::EntityData():
	mNode(),
	mMaterial()
{
	mActive = false;
	mChanged = false;
	mMeshIndex = 0;
}

int EntityData::getMeshIndex() const{
	return mMeshIndex;
}

const ofNode& EntityData::getTransform() const{
	return mNode;
}

const MaterialProperties& EntityData::getMaterial() const{
	return mMaterial;
}

void EntityData::setMeshIndex(int meshIndex){
	mMeshIndex = meshIndex;
}

void EntityData::setTransform(const ofNode& node){
	mNode = node; // should call copy constructor
}

void EntityData::setMaterial(const MaterialProperties& material){
	mMaterial = material; // should call copy constructor
}

// attempt to load pixel data. return false on error.
bool EntityData::load(const ofFloatPixels& pixels, int scanline_index){
	// check number of channels (expecting RGBA format)
	int channels = pixels.getNumChannels();
	if(channels != 4){
		ofLogError("EntityData") << "Expected image to have 4 channels (RGBA) but only found " << channels << " channels.";
		
		return false;
	}
	
	// load in the data
	float mesh_index = pixels.getColor(0, scanline_index).r;
	
	
	const ofFloatColor c1 = pixels.getColor(1, scanline_index);
	const ofFloatColor c2 = pixels.getColor(2, scanline_index);
	const ofFloatColor c3 = pixels.getColor(3, scanline_index);
	const ofFloatColor c4 = pixels.getColor(4, scanline_index);

	glm::mat4x4 mat = colors_to_mat4(c1, c2, c3, c4);
	
	
	int starting_index = 5;
	int num_pixels = mMaterial.getNumPixels();
	int max_num_material_pixels = pixels.getWidth() - starting_index;
	
	if(num_pixels > max_num_material_pixels){
		ofLogError("EntityData") << "Too many pixels required to pack the material properties. Requsted " << num_pixels << " pixels, but only have space for " << max_num_material_pixels << " pixels in this image.";
		
		return false;
	}
	
	mMaterial.load( pixels.getConstLine(scanline_index).getPixels(starting_index, num_pixels) );
	
	
	return true; // if you do all operations, there was no error
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
bool EntityCache::load(const ofFloatPixels& pixels){
	pixels.getWidth();
	pixels.getHeight();
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
void EntityCache::update(ofFloatPixels& pixels){
	
}


// write ALL data to pixels
void EntityCache::flush(ofFloatPixels& pixels){
	
}


EntityData& EntityCache::getEntity(int index){
	return mStorage[index];
}

// // cache will mark an unused entry in the pool for use and return the index
// int EntityCache::createEntity(){
	
// }

// // mark a used entry in the pool as no longer being used
// void EntityCache::destroyEntity(int index){
	
// }

