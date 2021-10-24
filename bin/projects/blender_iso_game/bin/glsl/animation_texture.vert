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
uniform sampler2DRect object_transform_tex;

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
    // 
    // GPU instancing - transform the entire object
    // 
    
    
    // 
    // v4.2
    // instancing data texture + lighting, scale magnitude by uniform
    // + width of texture comes from uniform
    // + transform matrix encoded in texture
    // ???
    
    // TODO: change name of texture to transform_tex, both here and when the texture is bound in the instancing material
    
    
    // https://stackoverflow.com/questions/13633395/how-do-you-access-the-individual-elements-of-a-glsl-mat4
    
    
    vec2 texCoord0 = vec2(0, gl_InstanceID) + vec2(0.5, 0.5);
    vec2 texCoord1 = vec2(1, gl_InstanceID) + vec2(0.5, 0.5);
    vec2 texCoord2 = vec2(2, gl_InstanceID) + vec2(0.5, 0.5);
    vec2 texCoord3 = vec2(3, gl_InstanceID) + vec2(0.5, 0.5);
    vec2 texCoord4 = vec2(4, gl_InstanceID) + vec2(0.5, 0.5);
    
    // mat4 transform = mat4(vec4(1,0,0,0),
    //                       vec4(0,1,0,0),
    //                       vec4(0,0,1,0),
    //                       vec4(1,1,1,1));
    
    // ^ yes indeed, matricies are column major
    // https://stackoverflow.com/questions/33807535/translation-in-glsl-shader
    
    vec4 loc   = TEXTURE(object_transform_tex, texCoord1);
    vec4 rot   = TEXTURE(object_transform_tex, texCoord2);
    vec4 scale = TEXTURE(object_transform_tex, texCoord3);
    
    
    mat4 transform = mat4(vec4(scale.r, 0, 0, 0),
                          vec4(0, scale.g, 0, 0),
                          vec4(0, 0, scale.b, 0),
                          vec4(loc.r, loc.g, loc.b, 1));
    
    vec4 object_data = TEXTURE(object_transform_tex, texCoord0);
    
    // vec4 finalPos = transform * position;
    
    
    // 
    // OpenEXR: vertex positions
    // 
    
    // vec4 finalPos = position;
    // vec4 finalNormal = normal;
    
    // vec2 texCoord0 = texcoord;
    vec2 vert_data_texcoord = texcoord + vec2(0.5,0.5) + vec2(0,object_data.r);
    vec4 pos_data  = TEXTURE(vert_pos_tex, vert_data_texcoord);
    
    // vec3 position = pos_data .rgb;
    // vec3 position = vec3(0,0,0);
    
    // vec4 finalPos = vec4(pos_data .rgb, 1.0);
     vec4 finalPos = transform * vec4(pos_data .rgb, 1.0);
    
    
    
    vec4 normal_data = TEXTURE(vert_norm_tex, vert_data_texcoord);
    vec4 finalNormal = vec4(normal_data.rgb, 0);
    
    // vec4 finalNormal = vec4(1,0,0,0);
    
    
    // v_color = vec4(pos_data .rgb, 1.0);
    // v_color = vec4(loc.rgb, 1.0);
    // v_color = vec4(scale.rgb, 1.0);
    v_color = vec4(finalNormal.rgb, 1.0);
    // v_color = vec4(1,1,1,1);
    
    // float x = object_data.r/3;
    // v_color = vec4(x,x,x, 1.0);
    
    
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
