    IN vec2 v_texcoord; // pass the texCoord if needed
    IN vec3 v_normal;
    IN vec3 v_transformedNormal;
    // Eye-coordinate position of vertex
    IN vec3 v_eyePosition;
    IN vec3 v_worldPosition;
    IN vec4 v_color;

#define TRANSPARENT_PASS 1
    struct lightData
    {
        float enabled;
        vec4 ambient;
        float type; // 0 = pointlight 1 = directionlight
        vec4 position; // where are we
        vec4 diffuse; // how diffuse
        vec4 specular; // what kinda specular stuff we got going on?
        // attenuation
        float constantAttenuation;
        float linearAttenuation;
        float quadraticAttenuation;
        // only for spot
        float spotCutoff;
        float spotCosCutoff;
        float spotExponent;
        // spot and area
        vec3 spotDirection;
        // only for directional
        vec3 halfVector;
        // only for area
        float width;
        float height;
        vec3 right;
        vec3 up;
    };

    uniform SAMPLER tex0;

    uniform vec4 mat_ambient;
    uniform vec4 mat_diffuse;
    uniform vec4 mat_specular;
    uniform vec4 mat_emissive;
    uniform float mat_shininess;
    uniform vec4 global_ambient;

    // these are passed in from OF programmable renderer
    uniform mat4 modelViewMatrix;
    uniform mat4 projectionMatrix;
    uniform mat4 textureMatrix;
    uniform mat4 modelViewProjectionMatrix;
    
    uniform int num_lights;
    uniform lightData lights[10];

	%custom_uniforms%
    
    %postFragment%
    
    
    //////////////////////////////////////////////////////
    // here's the main method
    //////////////////////////////////////////////////////


    void main (void){
        
        vec4 localColor = vec4(1,0,1, 1);
        
        
        // #if TRANSPARENT_PASS
        if(mat_diffuse.a != 1){
            // ---transparent pass---
            
            float ai = mat_diffuse.a; // no alpha map, so all fragments have same alpha
            float zi = v_eyePosition.z; // relative to the camera
            
            
            
            // trivial write to test things:
            // gl_FragData[0] = vec4(1,0,0, 1); // red silhouettes
            // gl_FragData[1] = vec4(1,1,0, 1); // yellow silhouettes
            
            
            // gl_FragData[0] = localColor;
            // gl_FragData[1] = localColor;
            
            
            gl_FragData[0] = vec4(localColor.rgb, ai);
            // gl_FragData[0] = vec4(localColor.rgb, ai) * w(zi, ai);
            gl_FragData[1] = vec4(ai);
            
            
            // gl_FragData[0] = vec4(vec3(1,1,1), (abs(zi)*0.04));
            // gl_FragData[0] = vec4(1,1,1,1);
        }else{
        // #else
        
            // ---opaque pass---
            
            // gl_FragColor = localColor;
            
            
            
            // gl_FragData[0] = vec4(0,1,0, 1); // green silhouettes
            
            gl_FragData[0] = localColor;
            
            
            
        // #endif
        
        }
    }
