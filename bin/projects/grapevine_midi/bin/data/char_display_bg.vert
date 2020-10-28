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


uniform vec2 origin;
// uniform vec3 charSize;

void main()
{
  colorVarying = color;
  texCoordVarying = (textureMatrix*vec4(texcoord.x,texcoord.y,0,1)).xy;
  gl_Position = modelViewProjectionMatrix * position;
}
