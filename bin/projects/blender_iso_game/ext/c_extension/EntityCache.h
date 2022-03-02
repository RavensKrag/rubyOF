#pragma once

#include "ofMain.h"

// must be AFTER OpenFrameworks includes, or compiler gets confused
// NOTE: Might be able to just run this 'include' from the main CPP file?
//       Not quite sure if I'll ever need the rice types in the header or not.
#include "rice/Data_Type.hpp"
#include "rice/Constructor.hpp"
#include "rice/Class.hpp"
#include "rice/Module.hpp"

#include "rice/Array.hpp"



#include "EntityData.h"


class EntityCache {
public:
	EntityCache(int max_size);
	~EntityCache();
	
	int getSize() const; // used if you want to interate over the entire cache
	
	bool load(const ofFloatPixels& pixels); // read from pixel data into cache
	bool update(ofFloatPixels& pixels);     // write changed data to pixels
	void flush(ofFloatPixels& pixels);      // write ALL data to pixels
	
	EntityData* getEntity(int index); // will always return non-null, but may not be an active entity
	int createEntity(); // cache will mark an unused entry in the pool for use and return the index
	void destroyEntity(int index); // mark a used entry in the pool as no longer being used
	
	
private:
	int mSize;
	EntityData* mpStorage = nullptr;
};
