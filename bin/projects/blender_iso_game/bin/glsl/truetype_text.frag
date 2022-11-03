// #version %glsl_version%
#version 150

// %extensions%

out vec4 fragColor;

uniform sampler2D trueTypeTexture;
uniform float usingTexture;
uniform float usingColors;
uniform vec4 globalColor;

in float depth;
in vec4 colorVarying;
in vec2 texCoordVarying;


void main(){
    fragColor = texture(trueTypeTexture, texCoordVarying);
}
