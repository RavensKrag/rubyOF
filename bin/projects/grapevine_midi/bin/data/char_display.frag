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
  vec4 text_color = vec4(1,0,0,1);
  
  // fragColor = texture(src_tex_unit0, texCoordVarying) * text_color;
  // fragColor = texture(fontColorMap, vec2(1,1));
    vec4 textTextureColor = texture(src_tex_unit0, texCoordVarying);
    
    vec4 colorMap_color = texture(fontColorMap, charVarying);
      // vec2 test = charVarying;
      // test.y = 1 + 0.5;
      // vec4 colorMap_color = texture(fontColorMap, test);
      
      // // boundaries appear to be replicating, rather than wrapping around
      // vec2 test = charVarying;
      // test.y = -10;
      // vec4 colorMap_color = texture(fontColorMap, test);
      
      
      // vec2 test = charVarying;
      // test.x=10;
      // if(charVarying.y > 0){
      //   test.y = 1;
      // }else if(charVarying.y < 0){
      //   test.y = 2;
      // }else{
      //   test.y = 10;
      // }
      
      
      // vec4 colorMap_color = texture(fontColorMap, test + vec2(0,0));
      
      // vec4 colorMap_color = texture(fontColorMap, test - vec2(0,0));
      
      
      
    fragColor = textTextureColor * colorMap_color;
  // fragColor = text_color;
}
