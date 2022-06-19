#include "EntityCache.h"



EntityCache::EntityCache(){
	mSize = 0;
}

EntityCache::~EntityCache(){
	delete mpStorage;
}

int
EntityCache::getSize() const{
	return mSize;
}

// read from pixel data into cache
// return false if there was an error with loading.
bool
EntityCache::load(const ofFloatPixels& pixels){
	int max_size = pixels.getHeight();
	
	if(max_size != mSize){
		if(mpStorage != nullptr){
			delete mpStorage;
		}
		
		mpStorage = new EntityData[max_size];
		mSize = max_size;
	}
	
	ofLogNotice("EntityCache") << "size:" << max_size;
	
	// scanline index 0 is blank data for mesh data, but not for entity data.
	// -- in the entity texture, every single non-blank row encodes real data
	
	// if the size is correct, then copy over all data into cache
	for(int i=0; i<mSize; i++){
		bool flag = mpStorage[i].load(pixels, i);
		if(!flag){
			ofLogError("EntityCache") <<  "Could not load entity data into cache. Problem parsing data on line " << i << "." << std::endl;
			return false;
		}
	}
	
	return true; // if you do all operations, there was no error
}

// write changed data to pixels
bool
EntityCache::update(ofFloatPixels& pixels){
	
	// check to make sure the ofPixels object is the correct size for this cache
	if(pixels.getHeight() != mSize){
		ofLogError("EntityCache") << "ofPixels object was the wrong size for this cache object.";
		return false;
	}
	
	// if the size is correct, then update all entries that need updating
	bool flag = false;
	for(int i=0; i<mSize; i++){
		bool line_flag = mpStorage[i].update(pixels, i);
		
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
	return &(mpStorage[index]);
}

// cache will mark an unused entry in the pool for use and return the index
int
EntityCache::createEntity(){
	for(int i=0; i<mSize; i++){
		if(!mpStorage[i].isActive()){ // find the first inactive EntityData object
			mpStorage[i].initialize(); // should set mActive = true
			return i;
		}
	}
	
	return -1;
}

// mark a used entry in the pool as no longer being used
void
EntityCache::destroyEntity(int index){
	mpStorage[index].destroy();
}

