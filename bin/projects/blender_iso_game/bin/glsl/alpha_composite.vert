#version 150

// OUT vec2 v_texcoord; // pass the texCoord if needed
// OUT vec3 v_transformedNormal;
// OUT vec3 v_normal;
// OUT vec3 v_eyePosition;
// OUT vec3 v_worldPosition;
// these outputs get passed to the next stage of the pipeline (to fragment)
out vec4 v_color;
out vec2 v_texcoord;
out vec4 v_normal;

in vec4 position;
in vec4 color;
in vec4 normal;
in vec2 texcoord;

// these are passed in from OF programmable renderer
uniform mat4 modelViewMatrix;
uniform mat4 modelMatrix;
uniform mat4 viewMatrix;
uniform mat4 projectionMatrix;
uniform mat4 textureMatrix;
uniform mat4 modelViewProjectionMatrix;

void main (void){
    gl_Position = modelViewProjectionMatrix * position;
    
    v_texcoord = gl_Position.xy;
}
