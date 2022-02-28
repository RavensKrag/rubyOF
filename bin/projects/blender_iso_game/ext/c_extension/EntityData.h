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



class EntityData {
public:
	// EntityData();
	// virtual ~EntityData(){};
	
	void initialize();
	void destroy();
	bool isActive() const;
	bool load(const ofFloatPixels& pixels, int scanline_index); // attempt to load pixel data. return false on error.
	bool update(ofFloatPixels& pixels, int scanline_index);
	
	int getMeshIndex() const;
	void setMeshIndex(int mesh_index);
	
	
	void copyMaterial(const EntityData& other);
	
	ofFloatColor getAmbient() const;
	ofFloatColor getDiffuse() const;
	ofFloatColor getSpecular() const;
	ofFloatColor getEmissive() const;
	float getAlpha() const;
	
	void setAmbient(const ofFloatColor& value);
	void setDiffuse(const ofFloatColor& value);
	void setSpecular(const ofFloatColor& value);
	void setEmissive(const ofFloatColor& value);
	void setAlpha(float value);
	
	
	void copyTransform(const EntityData& other);
	
	glm::vec3 getPosition() const;
	glm::quat getOrientation() const;
	glm::vec3 getScale() const;
	const glm::mat4& getTransformMatrix() const;
	
	void setPosition(const glm::vec3& value);
	void setOrientation(const glm::quat& value);
	void setScale(const glm::vec3& value);
	void setTransformMatrix(const glm::mat4& mat);
	

protected:
	void createMatrix();
	
	void loadMaterial(const ofFloatPixels::ConstPixels &scanline);
	void updateMaterial(ofFloatPixels& pixels, int scanline_index, int x_start);

private:	
	bool mActive;
	bool mChanged;
	
	int mMeshIndex;
	
	struct TransformComponent {
		glm::vec3 position;
		glm::quat orientation;
		glm::vec3 scale;
		glm::mat4 transform_matrix;
	} mTransform;
	
	struct MaterialComponent {
		static const int NUM_PIXELS = 4;
		
		ofFloatColor ambient;
		ofFloatColor diffuse;
		ofFloatColor specular;
		ofFloatColor emissive;
		float alpha;
	} mMaterial;
};

