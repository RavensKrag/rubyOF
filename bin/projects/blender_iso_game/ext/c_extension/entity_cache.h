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



class MaterialProperties {
public:
	// MaterialProperties();
	// virtual ~MaterialProperties(){};

	ofFloatColor getAmbient() const;
	ofFloatColor getDiffuse() const;
	ofFloatColor getSpecular() const;
	ofFloatColor getEmissive() const;
	float getAlpha();
	
	void setAmbient(const ofFloatColor& value);
	void setDiffuse(const ofFloatColor& value);
	void setSpecular(const ofFloatColor& value);
	void setEmissive(const ofFloatColor& value);
	void setAlpha(float value);
	
	int getNumPixels() const; // number of pixels needed to pack the data
	void load(const ofFloatPixels::ConstPixels &scanline);


private:
	ofFloatColor mAmbient;
	ofFloatColor mDiffuse;
	ofFloatColor mSpecular;
	ofFloatColor mEmissive;
	float mAlpha;
};





class EntityData {
public:
	EntityData();
	// virtual ~EntityData(){};
	
	int                       getMeshIndex() const;
	const ofNode&             getTransform() const;
	const MaterialProperties& getMaterial() const;
	
	void setMeshIndex(int meshIndex);
	void setTransform(const ofNode& node);
	void setMaterial(const MaterialProperties& material);
	
	bool load(const ofFloatPixels& pixels, int scanline_index); // attempt to load pixel data. return false on error.

	
private:
	bool mActive;
	bool mChanged;
	int mMeshIndex;
	ofNode mNode;
	MaterialProperties mMaterial;
};





class EntityCache {
public:
	EntityCache(int size);
	~EntityCache();
	
	bool load(const ofFloatPixels& pixels); // read from pixel data into cache
	void update(ofFloatPixels& pixels);     // write changed data to pixels
	void flush(ofFloatPixels& pixels);      // write ALL data to pixels
	
	EntityData& getEntity(int index);
	int createEntity(); // cache will mark an unused entry in the pool for use and return the index
	void destroyEntity(int index); // mark a used entry in the pool as no longer being used
	
private:
	int mSize;
	EntityData* mStorage = nullptr;
};
