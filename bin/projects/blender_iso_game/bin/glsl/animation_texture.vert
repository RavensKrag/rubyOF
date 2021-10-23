OUT vec2 v_texcoord; // pass the texCoord if needed
OUT vec3 v_transformedNormal;
OUT vec3 v_normal;
OUT vec3 v_eyePosition;
OUT vec3 v_worldPosition;
// #if HAS_COLOR
OUT vec4 v_color;
// #endif

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

// uniform float instance_scale;
// uniform int tex_width;

// uniform sampler2DRect position_tex;
// uniform sampler2DRect transform_tex;

uniform sampler2DRect vert_pos_tex;
uniform sampler2DRect vert_norm_tex;

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



// https://gamedev.stackexchange.com/questions/173220/quaternion-rotation-is-inverse-of-what-i-expect
// https://twistedpairdevelopment.wordpress.com/2013/02/11/rotating-a-vector-by-a-quaternion-in-glsl/
// vec3 rotate_vector( vec4 quat, vec3 vec )
// {
//     return vec + 2.0 * cross( cross( vec, quat.xyz ) + quat.w * vec, quat.xyz );
// }

 vec4 multQuat(vec4 q1, vec4 q2)
{
return vec4(
q1.w * q2.x + q1.x * q2.w + q1.z * q2.y - q1.y * q2.z,
q1.w * q2.y + q1.y * q2.w + q1.x * q2.z - q1.z * q2.x,
q1.w * q2.z + q1.z * q2.w + q1.y * q2.x - q1.x * q2.y,
q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z
);
}

vec3 rotate_vector( vec4 quat, vec3 vec )
{
vec4 qv = multQuat( quat, vec4(vec, 0.0) );
return multQuat( qv, vec4(-quat.x, -quat.y, -quat.z, quat.w) ).xyz;
}



void main (void){
    // vec4 finalPos = position;
    // vec4 finalNormal = normal;
    
    // vec2 texCoord0 = texcoord;
    vec2 texCoord0 = texcoord + vec2(0.5,0.5) + vec2(0,1);
    vec4 color_info = TEXTURE(vert_pos_tex, texCoord0);
    
    // vec3 position = color_info.rgb;
    // vec3 position = vec3(0,0,0);
    
    vec4 finalPos = vec4(color_info.rgb, 1.0);
    
    
    vec4 normal_data = TEXTURE(vert_norm_tex, texCoord0);
    vec4 finalNormal = vec4(normal_data.rgb, 0);
    
    // vec4 finalNormal = vec4(1,0,0,0);
    
    
    v_color = vec4(color_info.rgb, 1.0);
    // v_color = vec4(finalNormal.rgb, 1.0);
    // v_color = vec4(1,1,1,1);
    
    
    // NOTE: may have to transform normals because of rotation? unclear
    
    
    
    
    vec4 eyePosition = modelViewMatrix * finalPos;
    vec3 tempNormal = (normalMatrix * finalNormal).xyz;
    v_transformedNormal = normalize(tempNormal);
    v_normal = finalNormal.xyz;
    v_eyePosition = (eyePosition.xyz) / eyePosition.w;
    //v_worldPosition = (inverse(viewMatrix) * modelViewMatrix * finalPos).xyz;
    v_worldPosition = (finalPos).xyz;

    v_texcoord = (textureMatrix*vec4(texcoord.x,texcoord.y,0,1)).xy;
    // #if HAS_COLOR
    //     v_color = color;
    // #endif
    gl_Position = modelViewProjectionMatrix * finalPos;
}
