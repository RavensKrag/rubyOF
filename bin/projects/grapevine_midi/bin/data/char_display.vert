// vertex shader

#version 150

// these are for the programmable pipeline system and are passed in
// by default from OpenFrameworks

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform mat4 textureMatrix;
uniform mat4 modelViewProjectionMatrix;

in vec4  position;
in vec2  texcoord;
in vec4  color;
in vec3  normal;

// these outputs get passed to the next stage of the pipeline (to fragment)
out vec4 colorVarying;
out vec2 texCoordVarying;
out vec4 normalVarying;

// custom
out vec2 charVarying;

uniform vec2 origin;
uniform vec3 charSize;

void main()
{
  colorVarying = color;
  texCoordVarying = (textureMatrix*vec4(texcoord.x,texcoord.y,0,1)).xy;
  gl_Position = modelViewProjectionMatrix * position;
  
  
  
  vec2 charScaling;
  charScaling.x = charSize.z; // em_width
  // charScaling.y = charSize.x - charSize.y; // ascender_h - descender_h
  charScaling.y = 37; // ascender_h - descender_h
  
  
  // charVarying = (position.xy + vec2(0, 0) ) / charScaling;
  
  // charVarying = (position.xy + vec2(0, 28.46+7.23-7)) / vec2(18,28.46+7.23);
  // // the base grid is already offset by the ascender, so you only need to compensate by the descender in the shader
  
  charVarying = (position.xy + vec2(0, charScaling.y+charSize.y+0.5))/charScaling;
}
