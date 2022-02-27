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



class MaterialComponent {
public:
	MaterialComponent(bool* update_flag);
	// virtual ~MaterialComponent(){};
	
	void copyMaterial(MaterialComponent& material);
	
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
	void update(ofFloatPixels& pixels, int scanline_index, int x_start);


private:
	bool* mpUpdateFlag;
	
	ofFloatColor mAmbient;
	ofFloatColor mDiffuse;
	ofFloatColor mSpecular;
	ofFloatColor mEmissive;
	float mAlpha;
};





class TransformComponent {
public:
	TransformComponent(bool* update_flag);
	// virtual ~TransformComponent(){};
	
	const glm::mat4& getTransformMatrix() const;
	glm::vec3 getPosition() const;
	glm::quat getOrientation() const;
	glm::vec3 getScale() const;
	
	void setTransformMatrix(const glm::mat4& mat);
	void setPosition(const glm::vec3& value);
	void setOrientation(const glm::quat& value);
	void setScale(const glm::vec3& value);
	
protected:
	void createMatrix();

private:
	bool* mpUpdateFlag;
	
	glm::vec3 mPosition;
	glm::quat mOrientation;
	glm::vec3 mScale;
	glm::mat4 mLocalTransform;
};





class EntityData {
public:
	EntityData();
	// virtual ~EntityData(){};
	
	int getMeshIndex() const;
	void setMeshIndex(int mesh_index);
	
	TransformComponent& getTransformComponent();
	MaterialComponent& getMaterialComponent();
	
	bool load(const ofFloatPixels& pixels, int scanline_index); // attempt to load pixel data. return false on error.
	bool update(ofFloatPixels& pixels, int scanline_index);

	
private:	
	bool mActive;
	bool mChanged;
	int mMeshIndex;
	TransformComponent mTransform;
	MaterialComponent mMaterial;
};





class EntityCache {
public:
	EntityCache(int size);
	~EntityCache();
	
	bool load(const ofFloatPixels& pixels); // read from pixel data into cache
	bool update(ofFloatPixels& pixels);     // write changed data to pixels
	void flush(ofFloatPixels& pixels);      // write ALL data to pixels
	
	EntityData& getEntity(int index);
	int createEntity(); // cache will mark an unused entry in the pool for use and return the index
	void destroyEntity(int index); // mark a used entry in the pool as no longer being used
	
private:
	int mSize;
	EntityData* mStorage = nullptr;
};
