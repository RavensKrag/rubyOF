// vertex shader

#version 150

// // these are for the programmable pipeline system and are passed in
// // by default from OpenFrameworks
// uniform mat4 modelViewMatrix;
// uniform mat4 projectionMatrix;
// uniform mat4 textureMatrix;
// uniform mat4 modelViewProjectionMatrix;

// in vec4 position;
// in vec4 color;
// in vec4 normal;
// in vec2 texcoord;
// // this is the end of the default functionality

// // this is something we're creating for this shader


uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform mat4 textureMatrix;
uniform mat4 modelViewProjectionMatrix;

in vec4  position;
in vec2  texcoord;
in vec4  color;
in vec3  normal;

out vec4 colorVarying;
out vec2 texCoordVarying;
out vec4 normalVarying;

void main()
{
  colorVarying = color;
  texCoordVarying = (textureMatrix*vec4(texcoord.x,texcoord.y,0,1)).xy;
  gl_Position = modelViewProjectionMatrix * position;
}
