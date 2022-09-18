#pragma once

// #include "ofMath.h"

// #include "ofMain.h"

#include "ofMath.h"
#include "ofVectorMath.h"

void decompose_matrix(const glm::mat4& m, glm::vec3& pos, glm::quat& rot, glm::vec3& scale);