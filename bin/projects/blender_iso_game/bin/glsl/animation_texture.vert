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



// 
// Combines GPU instancing (draw the same mesh in many places)
// with vertex animation textures (draw many meshes with the same input mesh)
// 
// Resources:
//   GPU instancing:
//   + "4,000 Adams at 90 Frames Per Second"
//     by Yi Fei Boon, 2017/05 @ Casual Connect Asia 2017
//     https://www.youtube.com/watch?v=rXqKu9uC0f4
//   
//   Vertex animation textures:
//   + "The Illusion of Motion: Making Magic with Textures in the Vertex Shader"
//     by Mario Palmero, 2017/03 @ GDC 2017
//   
//   + "Vertex animation textures, beanbags and boneless animations."
//     by Martin Donald, 2020/10
void main (void){
    
    vec2 offset = vec2(0.5, 0.5);
    // TODO: change name of texture to transform_tex, both here and when the texture is bound in the instancing material
    
    
    
    // 
    // instance ID -> texcoords for object_transform_tex
    // 
    
    // Bottom row, y=0 is a line of magenta pixels.
    // This is used only as a visual indicator
    // of where the bottom of the texture is
    // it is not intended to be read as data.
    // Thus, the shader must +1 to the index.
    
    vec2 texCoord0 = vec2(0, gl_InstanceID+1) + offset;
    vec2 texCoord1 = vec2(1, gl_InstanceID+1) + offset;
    vec2 texCoord2 = vec2(2, gl_InstanceID+1) + offset;
    vec2 texCoord3 = vec2(3, gl_InstanceID+1) + offset;
    vec2 texCoord4 = vec2(4, gl_InstanceID+1) + offset;
    
    
    // 
    // mat4 transformation matrix from object_transform_tex
    // (converts local to world space)
    // 
    
    vec4 v1 = TEXTURE(object_transform_tex, texCoord1);
    vec4 v2 = TEXTURE(object_transform_tex, texCoord2);
    vec4 v3 = TEXTURE(object_transform_tex, texCoord3);
    vec4 v4 = TEXTURE(object_transform_tex, texCoord4);
    
    // https://stackoverflow.com/questions/13633395/how-do-you-access-the-individual-elements-of-a-glsl-mat4
    
    // mat4 transform = mat4(vec4(1,0,0,0),
    //                       vec4(0,1,0,0),
    //                       vec4(0,0,1,0),
    //                       vec4(1,1,1,1));
    
    // ^ yes indeed, matricies are column major
    // https://stackoverflow.com/questions/33807535/translation-in-glsl-shader
    
    
    // matrix packing is different from Blender
    mat4 transform = mat4(vec4(v1.r, v2.r, v3.r, v4.r),
                          vec4(v1.g, v2.g, v3.g, v4.g),
                          vec4(v1.b, v2.b, v3.b, v4.b),
                          vec4(v1.a, v2.a, v3.a, v4.a));
    
    
    // 
    // instance ID -> object ID from object_transform_tex
    // 
    
    float object_id = TEXTURE(object_transform_tex, texCoord0).r;
    
    // 
    // vertex UVs on input mesh -> texture coordinates for output mesh data
    // 
    
    vec2 vert_data_texcoord = texcoord + offset + vec2(0, object_id);
    
    // 
    // vertex UVs on input mesh -> positions of verts saved in texture
    // 
    
    // vec4 finalPos = position;
    // vec4 finalNormal = normal;
    
    vec4 pos_data  = TEXTURE(vert_pos_tex, vert_data_texcoord);
    
    // vec3 position = pos_data.rgb;
    // vec3 position = vec3(0,0,0);
    
    // vec4 finalPos = vec4(pos_data.rgb, 1.0);
    vec4 finalPos = transform * vec4(pos_data.rgb, 1.0);
    
    
    // 
    // vertex UVs on input mesh -> normal vector data saved in texture
    // (not a normal map per say. this is an encoding of vertex normals.)
    // 
    
    vec4 normal_data = TEXTURE(vert_norm_tex, vert_data_texcoord);
    vec4 finalNormal = vec4(normal_data.rgb, 0);
    
    // vec4 finalNormal = vec4(1,0,0,0);
    
    
    // 
    // output data as color for debugging
    // (need to set fragment shader to "phong_test.frag")
    // 
    
    // v_color = vec4(pos_data.rgb, 1.0);
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
