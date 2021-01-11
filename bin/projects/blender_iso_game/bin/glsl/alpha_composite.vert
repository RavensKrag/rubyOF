// #version %glsl_version%
#version 150

// %extensions%

#define IN in
#define OUT out
#define TEXTURE texture


uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;
uniform mat4 textureMatrix;
uniform mat4 modelViewProjectionMatrix;

IN vec4  position;
IN vec2  texcoord;
IN vec4  color;
IN vec3  normal;

OUT vec4 colorVarying;
OUT vec2 texCoordVarying;
OUT vec4 normalVarying;

void main()
{
	colorVarying = color;
	texCoordVarying = (textureMatrix*vec4(texcoord.x,texcoord.y,0,1)).xy;
	gl_Position = modelViewProjectionMatrix * position;
}
