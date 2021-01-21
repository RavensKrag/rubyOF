// #version %glsl_version%
#version 150

// %extensions%

#define IN in
#define OUT out
#define TEXTURE texture
#define FRAG_COLOR fragColor

out vec4 fragColor;

uniform sampler2DRect src_tex_unit0;
uniform sampler2DRect src_tex_unit1;
// uniform float usingTexture;
// uniform float usingColors;
uniform vec4 globalColor;

IN float depth;
IN vec4 colorVarying;
IN vec2 texCoordVarying;


void main(){
    FRAG_COLOR = TEXTURE(src_tex_unit0, texCoordVarying);
    
    
    
    
    // weighted sum of color / alpha
    vec4 accum = texture(src_tex_unit0, texCoordVarying);
    
    // revealage (inverse of coverage)
    float r    = texture(src_tex_unit1, texCoordVarying).r;
    
    
    // HDR-style : will clamp in the final compositing phase
    // TODO: may need to clamp here (test this first and find out???)
    
    
    // FRAG_COLOR = accum;
    
    
    fragColor = vec4(accum.rgb / clamp(accum.a, 1e-4, 5e4), r);
    // fragColor = vec4(vec3(1,0,0), 1);
    // fragColor = vec4(1,1,1,1);
    
    
    // FRAG_COLOR = vec4(TEXTURE(src_tex_unit0, texCoordVarying).rgb,
    //                   TEXTURE(src_tex_unit1, texCoordVarying).r)*globalColor;
    
    
    // FRAG_COLOR = vec4(TEXTURE(src_tex_unit0, texCoordVarying).rgb, 1);
}
