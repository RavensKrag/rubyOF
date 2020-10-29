// fragment shader

#version 150


out vec4 fragColor;

// uniform sampler2D src_tex_unit0;
uniform sampler2DRect bgColorMap;
uniform float usingTexture;
uniform float usingColors;
uniform vec4 globalColor;

in float depth;
in vec4 colorVarying;
in vec2 texCoordVarying;



void main(){
 vec4 textTextureColor = texture(bgColorMap, texCoordVarying + vec2(0.5,0.5));
 
 // vec4 textTextureColor = texture(src_tex_unit0, vec2(14, 19));
 // vec4 textTextureColor = texture(src_tex_unit0, vec2(49, 1));
 // vec4 textTextureColor = vec4(texCoordVarying.x/100,0,0,1);
 
 
 fragColor = textTextureColor;
 
 // fragColor = vec4(1,0,0, 1);
}
