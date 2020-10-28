// fragment shader

#version 150


out vec4 fragColor;

uniform sampler2D src_tex_unit0;
uniform float usingTexture;
uniform float usingColors;
uniform vec4 globalColor;

in float depth;
in vec4 colorVarying;
in vec2 texCoordVarying;

// custom
in vec2 charVarying;

uniform sampler2DRect fontColorMap;

void main(){
  // vec4 text_color = vec4(1,0,0,1);
  
  // fragColor = texture(src_tex_unit0, texCoordVarying) * text_color;
  // fragColor = texture(fontColorMap, vec2(1,1));
    vec4 textTextureColor = texture(src_tex_unit0, texCoordVarying);
    
    vec4 colorMap_color = texture(fontColorMap, charVarying);
      
      
    fragColor = textTextureColor * colorMap_color;
    // fragColor = textTextureColor;
  // fragColor = text_color;
}
