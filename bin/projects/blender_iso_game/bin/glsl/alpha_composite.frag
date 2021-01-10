// fragment shader

#version 150

// these are passed in from OF programmable renderer
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform mat4 textureMatrix;
uniform mat4 modelViewProjectionMatrix;

uniform float usingTexture;
uniform float usingColors;
uniform vec4 globalColor;

uniform sampler2DRect accumTexture;
uniform sampler2DRect revealageTexture;

out vec4 fragColor;

void main (void){
    ivec2 tex_pos = ivec2(gl_FragCoord.x, gl_FragCoord.y);
    
    // weighted sum of color / alpha
    vec4 accum = texture(accumTexture, tex_pos);
    
    // revealage (inverse of coverage)
    float r = texture(revealageTexture, tex_pos).r;
    
    
    // HDR-style : will clamp in the final compositing phase
    // TODO: may need to clamp here (test this first and find out???)
    
    // fragColor = vec4(accum.rgb / clamp(accum.a, 1e-4, 5e4), r);
    fragColor = vec4(1,0,0,1);
}
