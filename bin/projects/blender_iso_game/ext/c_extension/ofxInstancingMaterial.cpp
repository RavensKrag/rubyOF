#include "ofxInstancingMaterial.h"
#include "ofConstants.h"
#include "ofLight.h"
#include "ofGLProgrammableRenderer.h"

using namespace std;

std::map<ofGLProgrammableRenderer*, std::map<std::string, std::weak_ptr<ofxInstancingMaterial::Shaders>>> ofxInstancingMaterial::shadersMap;



ofxInstancingMaterial::ofxInstancingMaterial() {
}

void ofxInstancingMaterial::setColors(ofFloatColor oDiffuse, ofFloatColor oAmbient, ofFloatColor oSpecular, ofFloatColor oEmissive) {
	setDiffuseColor(oDiffuse);
	setAmbientColor(oAmbient);
	setSpecularColor(oSpecular);
	setEmissiveColor(oEmissive);
}


void ofxInstancingMaterial::setup(const ofxInstancingMaterialSettings & settings){
	if(settings.customUniforms != data.customUniforms || settings.postFragment != data.postFragment){
		shaders.clear();
	}
	data = settings;
}

void ofxInstancingMaterial::setDiffuseColor(ofFloatColor oDiffuse) {
	data.diffuse = oDiffuse;
}

void ofxInstancingMaterial::setAmbientColor(ofFloatColor oAmbient) {
	data.ambient = oAmbient;
}

void ofxInstancingMaterial::setSpecularColor(ofFloatColor oSpecular) {
	data.specular = oSpecular;
}

void ofxInstancingMaterial::setEmissiveColor(ofFloatColor oEmissive) {
	data.emissive = oEmissive;
}

void ofxInstancingMaterial::setShininess(float nShininess) {
	data.shininess = nShininess;
}

void ofxInstancingMaterial::setData(const ofxInstancingMaterial::Data &data){
	setup(data);
}

float ofxInstancingMaterial::getShininess()const{
	return data.shininess;
}

ofFloatColor ofxInstancingMaterial::getDiffuseColor()const {
	return data.diffuse;
}

ofFloatColor ofxInstancingMaterial::getAmbientColor()const {
	return data.ambient;
}

ofFloatColor ofxInstancingMaterial::getSpecularColor()const {
	return data.specular;
}

ofFloatColor ofxInstancingMaterial::getEmissiveColor()const {
	return data.emissive;
}

ofxInstancingMaterialSettings ofxInstancingMaterial::getSettings() const{
    return data;
}

void ofxInstancingMaterial::begin() const{
	if(ofGetGLRenderer()){
		ofGetGLRenderer()->bind(*this);
	}
}

void ofxInstancingMaterial::end() const{
	if(ofGetGLRenderer()){
		ofGetGLRenderer()->unbind(*this);
	}
}

void ofxInstancingMaterial::initShaders(ofGLProgrammableRenderer & renderer) const{
    auto rendererShaders = shaders.find(&renderer);
    if(rendererShaders == shaders.end() || rendererShaders->second->numLights != ofLightsData().size()){
        if(shadersMap[&renderer].find(data.postFragment)!=shadersMap[&renderer].end()){
            auto newShaders = shadersMap[&renderer][data.postFragment].lock();
            if(newShaders == nullptr || newShaders->numLights != ofLightsData().size()){
                shadersMap[&renderer].erase(data.postFragment);
                shaders[&renderer] = nullptr;
            }else{
                shaders[&renderer] = newShaders;
            }
        }
    }

    if(shaders[&renderer] == nullptr){
        #ifndef TARGET_OPENGLES
            string vertexRectHeader = renderer.defaultVertexShaderHeader(GL_TEXTURE_RECTANGLE);
            string fragmentRectHeader = renderer.defaultFragmentShaderHeader(GL_TEXTURE_RECTANGLE);
        #endif
        string vertex2DHeader = renderer.defaultVertexShaderHeader(GL_TEXTURE_2D);
        string fragment2DHeader = renderer.defaultFragmentShaderHeader(GL_TEXTURE_2D);
        auto numLights = ofLightsData().size();
        shaders[&renderer].reset(new Shaders);
        shaders[&renderer]->numLights = numLights;
        shaders[&renderer]->noTexture.setupShaderFromSource(GL_VERTEX_SHADER,vertexSource(vertex2DHeader,numLights,false,false));
        shaders[&renderer]->noTexture.setupShaderFromSource(GL_FRAGMENT_SHADER,fragmentSource(fragment2DHeader, data.customUniforms, data.postFragment,numLights,false,false));
        shaders[&renderer]->noTexture.bindDefaults();
        shaders[&renderer]->noTexture.linkProgram();

        shaders[&renderer]->texture2D.setupShaderFromSource(GL_VERTEX_SHADER,vertexSource(vertex2DHeader,numLights,true,false));
        shaders[&renderer]->texture2D.setupShaderFromSource(GL_FRAGMENT_SHADER,fragmentSource(fragment2DHeader, data.customUniforms, data.postFragment,numLights,true,false));
        shaders[&renderer]->texture2D.bindDefaults();
        shaders[&renderer]->texture2D.linkProgram();

        #ifndef TARGET_OPENGLES
            shaders[&renderer]->textureRect.setupShaderFromSource(GL_VERTEX_SHADER,vertexSource(vertexRectHeader,numLights,true,false));
            shaders[&renderer]->textureRect.setupShaderFromSource(GL_FRAGMENT_SHADER,fragmentSource(fragmentRectHeader, data.customUniforms, data.postFragment,numLights,true,false));
            shaders[&renderer]->textureRect.bindDefaults();
            shaders[&renderer]->textureRect.linkProgram();
        #endif

        shaders[&renderer]->color.setupShaderFromSource(GL_VERTEX_SHADER,vertexSource(vertex2DHeader,numLights,false,true));
        shaders[&renderer]->color.setupShaderFromSource(GL_FRAGMENT_SHADER,fragmentSource(fragment2DHeader, data.customUniforms, data.postFragment,numLights,false,true));
        shaders[&renderer]->color.bindDefaults();
        
            shaders[&renderer]->color.bindAttribute(5, "transformMatrix");
        
        shaders[&renderer]->color.linkProgram();
        
        
        shaders[&renderer]->texture2DColor.setupShaderFromSource(GL_VERTEX_SHADER,vertexSource(vertex2DHeader,numLights,true,true));
        shaders[&renderer]->texture2DColor.setupShaderFromSource(GL_FRAGMENT_SHADER,fragmentSource(fragment2DHeader, data.customUniforms, data.postFragment,numLights,true,true));
        shaders[&renderer]->texture2DColor.bindDefaults();
        shaders[&renderer]->texture2DColor.linkProgram();
        
        
        #ifndef TARGET_OPENGLES
            shaders[&renderer]->textureRectColor.setupShaderFromSource(GL_VERTEX_SHADER,vertexSource(vertexRectHeader,numLights,true,true));
            shaders[&renderer]->textureRectColor.setupShaderFromSource(GL_FRAGMENT_SHADER,fragmentSource(fragmentRectHeader, data.customUniforms, data.postFragment,numLights,true,true));
            shaders[&renderer]->textureRectColor.bindDefaults();
            shaders[&renderer]->textureRectColor.linkProgram();
        #endif
        
        
        
        // // void bindAttribute(GLuint location, const std::string & name) const;
        //     // attributesBindingsCache[name] = location;
        //     // glBindAttribLocation(program,location,name.c_str());


        // // void ofShader::setAttribute4fv(const string & name, const float* v, GLsizei stride)
        //     // if(bLoaded){
        //     // 	GLint location = getAttributeLocation(name);
        //     // 	if (location != -1) {
        //     // 		glVertexAttribPointer(location, 4, GL_FLOAT, GL_FALSE, stride, v);
        //     // 		glEnableVertexAttribArray(location);
        //     // 	}
        //     // }

        // GLuint program = shader.getProgram();
        // GLuint location = 5; // counts starts @ 0, 0-4 taken; see ofShader.h:250

        // glBindAttribLocation(program, location, "transformMatrix");


        // GLsizei stride = sizeof(float)*4;
        // glVertexAttribPointer(location, 4, GL_FLOAT, GL_FALSE, stride, &transform_mat4s[0]);
        // // ^ pointer to a std::vector is just the same as a C array pointer
        // glEnableVertexAttribArray(location);

        // shadersMap[&renderer][data.postFragment] = shaders[&renderer];
    }

}

const ofShader & ofxInstancingMaterial::getShader(int textureTarget, bool geometryHasColor, ofGLProgrammableRenderer & renderer) const{
    initShaders(renderer);
	switch(textureTarget){
	case OF_NO_TEXTURE:
        if(geometryHasColor){
            return shaders[&renderer]->color;
        }else{
            return shaders[&renderer]->noTexture;
        }
		break;
	case GL_TEXTURE_2D:
        if(geometryHasColor){
            return shaders[&renderer]->texture2DColor;
        }else{
            return shaders[&renderer]->texture2D;
        }
		break;
    default:
        if(geometryHasColor){
            return shaders[&renderer]->textureRectColor;
        }else{
            return shaders[&renderer]->textureRect;
        }
		break;
	}
}

void ofxInstancingMaterial::updateMaterial(const ofShader & shader,ofGLProgrammableRenderer & renderer) const{
	
	
	shader.setUniform4fv("mat_ambient", &data.ambient.r);
	shader.setUniform4fv("mat_diffuse", &data.diffuse.r);
	shader.setUniform4fv("mat_specular", &data.specular.r);
	shader.setUniform4fv("mat_emissive", &data.emissive.r);
	shader.setUniform4fv("global_ambient", &ofGetGlobalAmbientColor().r);
	shader.setUniform1f("mat_shininess",data.shininess);
    
    
    for (auto & uniform : uniformstex) {
        shader.setUniformTexture(uniform.first,
                                 uniform.second.textureTarget,
                                 uniform.second.textureID,
                                 uniform.second.textureLocation);
    }
}

void ofxInstancingMaterial::updateLights(const ofShader & shader,ofGLProgrammableRenderer & renderer) const{
	for(size_t i=0;i<ofLightsData().size();i++){
		string idx = ofToString(i);
		shared_ptr<ofLight::Data> light = ofLightsData()[i].lock();
		if(!light || !light->isEnabled){
			shader.setUniform1f("lights["+idx+"].enabled",0);
			continue;
		}
		auto lightEyePosition = renderer.getCurrentViewMatrix() * light->position;
		shader.setUniform1f("lights["+idx+"].enabled",1);
		shader.setUniform1f("lights["+idx+"].type", light->lightType);
		shader.setUniform4f("lights["+idx+"].position", lightEyePosition);
		shader.setUniform4f("lights["+idx+"].ambient", light->ambientColor);
		shader.setUniform4f("lights["+idx+"].specular", light->specularColor);
		shader.setUniform4f("lights["+idx+"].diffuse", light->diffuseColor);

		if(light->lightType!=OF_LIGHT_DIRECTIONAL){
			shader.setUniform1f("lights["+idx+"].constantAttenuation", light->attenuation_constant);
			shader.setUniform1f("lights["+idx+"].linearAttenuation", light->attenuation_linear);
			shader.setUniform1f("lights["+idx+"].quadraticAttenuation", light->attenuation_quadratic);
		}

		if(light->lightType==OF_LIGHT_SPOT){
			glm::vec3 direction = glm::vec3(light->position) + light->direction;
			glm::vec4 direction4 = renderer.getCurrentViewMatrix() * glm::vec4(direction,1.0);
			direction = glm::vec3(direction4) / direction4.w;
			direction = direction - glm::vec3(lightEyePosition);
			shader.setUniform3f("lights["+idx+"].spotDirection", glm::normalize(direction));
			shader.setUniform1f("lights["+idx+"].spotExponent", light->exponent);
			shader.setUniform1f("lights["+idx+"].spotCutoff", light->spotCutOff);
			shader.setUniform1f("lights["+idx+"].spotCosCutoff", cos(ofDegToRad(light->spotCutOff)));
		}else if(light->lightType==OF_LIGHT_DIRECTIONAL){
			glm::vec3 halfVector(glm::normalize(glm::vec4(0.f, 0.f, 1.f, 0.f) + lightEyePosition));
			shader.setUniform3f("lights["+idx+"].halfVector", halfVector);
		}else if(light->lightType==OF_LIGHT_AREA){
			shader.setUniform1f("lights["+idx+"].width", light->width);
			shader.setUniform1f("lights["+idx+"].height", light->height);
			glm::vec3 direction = glm::vec3(light->position) + light->direction;
			glm::vec4 direction4 = renderer.getCurrentViewMatrix() * glm::vec4(direction, 1.0);
			direction = glm::vec3(direction4) / direction4.w;
			direction = direction - glm::vec3(lightEyePosition);
			shader.setUniform3f("lights["+idx+"].spotDirection", glm::normalize(direction));
			glm::vec3 right = glm::vec3(light->position) + light->right;
			glm::vec4 right4 = renderer.getCurrentViewMatrix() * glm::vec4(right, 1.0);
			right = glm::vec3(right4) / right4.w;
			right = right - glm::vec3(lightEyePosition);
			auto up = glm::cross(right, direction);
			shader.setUniform3f("lights["+idx+"].right", glm::normalize(toGlm(right)));
			shader.setUniform3f("lights["+idx+"].up", glm::normalize(up));
		}
	}
}


void ofxInstancingMaterial::setCustomUniformTexture(const std::string & name, const ofTexture & value, int textureLocation){
    uniformstex[name] = {value.getTextureData().textureTarget, int(value.getTextureData().textureID), textureLocation};
}

void ofxInstancingMaterial::setCustomUniformTexture(const std::string & name, int textureTarget, GLint textureID, int textureLocation){
    uniformstex[name] = {textureTarget, textureID, textureLocation};
}


void ofxInstancingMaterial::setVertexShaderSource(const std::string &source){
    vertexShader = source;
    shaders.clear();
}

void ofxInstancingMaterial::setFragmentShaderSource(const std::string &source){
    fragmentShader = source;
    shaders.clear();
}




// #include "shaders/phong.vert"
// #include "shaders/phong_instanced.vert"
// #include "shaders/phong.frag"

string shaderHeader(string header, int maxLights, bool hasTexture, bool hasColor){
    header += "#define MAX_LIGHTS " + ofToString(max(1,maxLights)) + "\n";
    if(hasTexture){
        header += "#define HAS_TEXTURE 1\n";
	} else {
		header += "#define HAS_TEXTURE 0\n";
	}
    if(hasColor){
        header += "#define HAS_COLOR 1\n";
	} else {
		header += "#define HAS_COLOR 0\n";
	}
    return header;
}

std::string ofxInstancingMaterial::vertexSource(std::string defaultHeader, int maxLights, bool hasTexture, bool hasColor) const{
    return shaderHeader(defaultHeader, maxLights, hasTexture, hasColor) + vertexShader;
}

std::string ofxInstancingMaterial::fragmentSource(std::string defaultHeader, std::string customUniforms,  std::string postFragment, int maxLights, bool hasTexture, bool hasColor) const{
    auto source = fragmentShader;
    if(postFragment.empty()){
        postFragment = "vec4 postFragment(vec4 localColor){ return localColor; }";
    }
	ofStringReplace(source, "%postFragment%", postFragment);
	ofStringReplace(source, "%custom_uniforms%", customUniforms);

    source = shaderHeader(defaultHeader, maxLights, hasTexture, hasColor) + source;
    return source;
}
