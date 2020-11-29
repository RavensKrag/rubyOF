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

uniform SAMPLER position_tex;


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
    // v5
    // try using texture again
    //
    
    // v_color = color;
    float scale = 50;
    
    vec2 posTexCoord = vec2(gl_InstanceID/256, gl_InstanceID%256);
    
    vec4 pos_data = TEXTURE(position_tex, posTexCoord+vec2(0.5, 0.5));
    vec3 dirVec = vec3((pos_data.r*2)-1, (pos_data.g*2)-1, (pos_data.b*2)-1);
    vec4 finalPos = position + vec4(dirVec*scale, 0);
    
    
    
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
