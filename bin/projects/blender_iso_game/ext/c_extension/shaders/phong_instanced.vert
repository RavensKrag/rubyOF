OUT vec2 v_texcoord; // pass the texCoord if needed
OUT vec3 v_transformedNormal;
OUT vec3 v_normal;
OUT vec3 v_eyePosition;
OUT vec3 v_worldPosition;
#if HAS_COLOR
OUT vec4 v_color;
#endif

IN vec4 position;
IN vec4 color;
IN vec4 normal;
IN vec2 texcoord;

// these are passed in from OF programmable renderer
uniform mat4 modelViewMatrix;
uniform mat4 modelMatrix;
uniform mat4 viewMatrix;
uniform mat4 projectionMatrix;
uniform mat4 textureMatrix;
uniform mat4 modelViewProjectionMatrix;
uniform mat4 normalMatrix;

uniform sampler2DRect position_tex;
// there are two types for textures:
// sampler2DRect        non-normalized coordinates
// sampler2D            normalized coordinates
// 
// https://forum.openframeworks.cc/t/how-to-bind-a-texture-to-ofvbo-correctly/28143
// ^ explains differences between these two types,
//   and how they interact with ofDisableArbTex()
// 
// the shader #define macro SAMPLER will switch between the two
// depending on the OpenFrameworks mode / if there is a texture bound
// but I think that really only works for the basic first texture.
// Either way, better to just declare the sampler2DRect type here.


void main (void){
    // float instance_x = gl_InstanceID/256;
    // float instance_y = gl_InstanceID%256;
    // vec2 posTexCoord = vec2(instance_x, instance_y);
    
    // vec4 finalPos = position + TEXTURE(position_tex, posTexCoord);
    
    // vec4 eyePosition = modelViewMatrix * finalPos;
    // vec3 tempNormal = (normalMatrix * normal).xyz;
    // v_transformedNormal = normalize(tempNormal);
    // v_normal = normal.xyz;
    // v_eyePosition = (eyePosition.xyz) / eyePosition.w;
    // //v_worldPosition = (inverse(viewMatrix) * modelViewMatrix * finalPos).xyz;
    // v_worldPosition = (finalPos).xyz;

    // v_texcoord = (textureMatrix*vec4(texcoord.x,texcoord.y,0,1)).xy;
    // #if HAS_COLOR
    //     v_color = color;
    // #endif
    // gl_Position = modelViewProjectionMatrix * finalPos;
    
    
    
    // 
    // test data
    // 
    
    // (3.434, -10.038, 0.255)
    // [0.6618145108222961, 0.027060022577643394, 0.5119929909706116, 0.10611911863088608]

    
    
    
    // 
    // v5
    // try using texture again
    //
    
    // 
    // direct displacement
    // WORKS
    
    // vec3 displacement = vec3(3.434, -10.038, 0.255); // this works
    
    
    // 
    // displacement from encoded position
    // PASS
    
    // float scale = 100;
    
    // vec4 pos_data = vec4(0.6618145108222961, 0.027060022577643394, 0.5119929909706116, 0.10611911863088608);
    // vec3 dirVec = vec3((pos_data.r*2)-1, (pos_data.g*2)-1, (pos_data.b*2)-1);
    // vec3 displacement = dirVec*pos_data.a*scale;
    
    
    // 
    // displacement from texture data
    // PASS
    
    float scale = 100;
    
    vec2 posTexCoord = vec2(gl_InstanceID/256, gl_InstanceID%256);
    
    vec4 pos_data = TEXTURE(position_tex, posTexCoord+vec2(0.5, 0.5));
    // vec4 pos_data = vec4(0,0,0,0); // same as this. currently reading zero!
    vec3 dirVec = vec3((pos_data.r*2)-1, (pos_data.g*2)-1, (pos_data.b*2)-1);
    
    vec3 displacement = dirVec*pos_data.a*scale;
    
    
    
    
    
    
    vec4 finalPos = position + vec4(displacement, 0);
    
    
    
    // // 
    // // v4
    // // position cubes in a grid, specified by shader only
    // // PASS
    // // 
    
    // // v_color = color;
    // float scale = 4;
    
    // vec2 posTexCoord = vec2(gl_InstanceID/8, gl_InstanceID%8);
    
    // vec4 finalPos = position + vec4((posTexCoord*scale).xy, 0, 0);
    // // ^ positions likely not encoded correctly in texture.
    
    
    
    
    
    // // 
    // // v3
    // // position cubes in a line, specified by shader only
    // // PASS
    // // 
    
    // // v_color = color;
    // float scale = 4;
    
    // vec2 posTexCoord = vec2(gl_InstanceID, 0);
    
    // vec4 finalPos = position + vec4((posTexCoord*scale).xy, 0, 0);
    // // ^ positions likely not encoded correctly in texture.
    
    
    // // 
    // // v2
    // // FAIL 
    // //
    
    // // v_color = color;
    // float scale = 50;
    
    // float instance_x = gl_InstanceID/256;
    // float instance_y = gl_InstanceID%256;
    // vec2 posTexCoord = vec2(instance_x, instance_y);
    
    // vec4 pos_data = TEXTURE(position_tex, posTexCoord+vec2(0.5, 0.5));
    // vec3 dirVec = vec3((pos_data.r*2)-1, (pos_data.g*2)-1, (pos_data.b*2)-1);
    // vec4 finalPos = position + vec4(dirVec*scale, 0);
    // // ^ positions likely not encoded correctly in texture.
    
    
    // 
    // v1
    // 
    
    // vec4 texPos = vec4(6, -13, 0, 1);
    // vec4 finalPos = position + vec4(texPos.rgb, 0);
    
    gl_Position = modelViewProjectionMatrix * finalPos;
}
