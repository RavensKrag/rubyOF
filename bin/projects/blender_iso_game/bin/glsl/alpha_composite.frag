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

in vec2 v_texcoord;

out vec4 fragColor;

void main (void){
    
    // 
    // test pattern to try and figure out the coordinate system
    // 
    
    int pos_x = int(v_texcoord.x + 1000);
    int pos_y = int(v_texcoord.y + 900);
    
    if(pos_x < 0){
        pos_x = 0;
    }
    if(pos_y < 0){
        pos_y = 0;
    }
    
    float i = (pos_x%200);
    float j = (pos_y%200);
    fragColor = vec4((200-i)/200, (200-j)/200, 0, 1);
    
    
    
    // 
    // attempts to actually implement the shader below
    // 
    
    
    
    
    ivec2 tex_pos = ivec2(gl_FragCoord.x, gl_FragCoord.y);
    
    // weighted sum of color / alpha
    vec4 accum = texture(accumTexture, 
                         vec2(v_texcoord.x, 
                              v_texcoord.y));
    
    // revealage (inverse of coverage)
    float r = texture(revealageTexture, tex_pos).r;
    
    
    // HDR-style : will clamp in the final compositing phase
    // TODO: may need to clamp here (test this first and find out???)
    
    // accum = texture(accumTexture, vec2(v_texcoord.x + 1000, v_texcoord.y + 900));
    // fragColor = accum;
    
    
    
    // fragColor = vec4(((v_texcoord.x+500)/2072), 0, 0, 1);
    
    
    
    
    // fragColor = vec4(vec3(1,0,0), accum.a);
    
    
    // fragColor = texture(accumTexture, vec2(v_texcoord.x+500/2072, v_texcoord.y/1000));
    
    
    
    // fragColor = accum.rgba;
    
    fragColor = vec4(accum.rgb, 1);
    
    // fragColor = vec4(accum.rgb / clamp(accum.a, 1e-4, 5e4), r);
    // fragColor = vec4(vec3(1,0,0), 1);
    // fragColor = vec4(1,1,1,1);
}
