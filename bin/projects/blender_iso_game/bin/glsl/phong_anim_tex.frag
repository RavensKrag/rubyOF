    IN vec2 v_texcoord; // pass the texCoord if needed
    IN vec3 v_normal;
    IN vec3 v_transformedNormal;
    // Eye-coordinate position of vertex
    IN vec3 v_eyePosition;
    IN vec3 v_worldPosition;
    IN vec4 v_lightSpacePosition;
// #if HAS_COLOR
    IN vec4 v_ambient;
    IN vec4 v_diffuse;
    IN vec4 v_specular;
    IN vec4 v_emissive;
    IN float v_transparent_pass;
    
// #endif

    struct lightData
    {
        float enabled;
        vec4 ambient;
        float type; // 0 = pointlight 1 = directionlight
        vec4 position; // where are we
        vec3 direction; // orientation of the light in view space
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
        // only for directional
        vec3 halfVector;
        // only for area
        float width;
        float height;
        vec3 right;
        vec3 up;
    };

    uniform SAMPLER tex0;
    
    uniform sampler2D shadow_tex;
    // ofMaterial textures are bound by name, but ofShader textures are bound by slot number
    uniform sampler2DRect src_tex_unit0;
    uniform sampler2DRect src_tex_unit1;
    uniform sampler2DRect src_tex_unit2;
    uniform sampler2D src_tex_unit3;

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

    uniform float u_shadowWidth;
    uniform float u_shadowHeight;
    uniform float u_shadowIntensity;
    uniform float u_shadowBias;

    uniform int num_lights;
    uniform lightData lights[10];

	%custom_uniforms%
    
    
    
    
    float lerp(float a, float b, float t){
        float value;
        value = (1.0f - t) * a + b * t;
        return value;
    }
    
    float invlerp(float a, float b, float value){
        float t;
        t = (value - a) / (b - a);
        return t;
    }
    
    float remap(float iMin, float iMax, float oMin, float oMax, float v){
        float t = invlerp(iMin, iMax, v);
        return lerp(oMin, oMax, t);
    }
    
    // similar to clamp,
    // but values outside the range are set to 0
    float clip(float value, float a, float b){
        if(value > b){
            value = 0.0;
        }
        if(value < a){
            value = 0.0;
        }
        return value;
    }
    
    
    
    


    void pointLight( in lightData light, in vec3 normal, in vec3 ecPosition3, inout vec3 ambient, inout vec3 diffuse, inout vec3 specular ){
        float nDotVP;       // normal . light direction
        float nDotHV;       // normal . light half vector
        float pf;           // power factor
        float attenuation;  // computed attenuation factor
        float d;            // distance from surface to light source
        vec3  VP;           // direction from surface to light position
        vec3  halfVector;   // direction of maximum highlights
        vec3 eye = -normalize(v_eyePosition);

        // Compute vector from surface to light position
        VP = vec3 (light.position.xyz) - ecPosition3;

        // Compute distance between surface and light position
        d = length(VP);


        // Compute attenuation
        attenuation = 1.0 / (light.constantAttenuation + light.linearAttenuation * d + light.quadraticAttenuation * d * d);

        // Normalize the vector from surface to light position
        VP = normalize(VP);
        halfVector = normalize(VP + eye);
        nDotHV = max(0.0, dot(normal, halfVector));
        nDotVP = max(0.0, dot(normal, VP));

        ambient += light.ambient.rgb * attenuation;
        diffuse += light.diffuse.rgb * nDotVP * attenuation;
#ifndef TARGET_OPENGLES
#define SPECULAR_REFLECTION
#endif
#ifndef SPECULAR_REFLECTION
        // ha! no branching :)
        pf = mix(0.0, pow(nDotHV, mat_shininess), step(0.0000001, nDotVP));
        specular += light.specular.rgb * pf * nDotVP * attenuation;
#else
        // fresnel factor
        // http://en.wikibooks.org/wiki/GLSL_Programming/Unity/Specular_Highlights_at_Silhouettes
        float w = pow(1.0 - max(0.0, dot(halfVector, VP)), 5.0);
        vec3 specularReflection = attenuation * vec3(light.specular.rgb)
          * mix(vec3(mat_specular.rgb), vec3(1.0), w)
          * pow(nDotHV, mat_shininess);
        specular += mix(vec3(0.0), specularReflection, step(0.0000001, nDotVP));
#endif
    }

    void directionalLight(in lightData light, in vec3 normal, inout vec3 ambient, inout vec3 diffuse, inout vec3 specular){
        float nDotVP;         // normal . light direction
        float nDotHV;         // normal . light half vector
        float pf;             // power factor

        nDotVP = max(0.0, dot(normal, normalize(vec3(light.direction) * -1)));
        nDotHV = max(0.0, dot(normal, light.halfVector));

        pf = mix(0.0, pow(nDotHV, mat_shininess), step(0.0000001, nDotVP));

        ambient += light.ambient.rgb;
        diffuse += light.diffuse.rgb * nDotVP;
        specular += light.specular.rgb * pf * nDotVP;
    }

    void spotLight(in lightData light, in vec3 normal, in vec3 ecPosition3, inout vec3 ambient, inout vec3 diffuse, inout vec3 specular){
        float nDotVP; // = max(dot(normal,normalize(vec3(light.position))),0.0);
        float nDotHV;       // normal . light half vector
        float pf;
        float d;            // distance from surface to light source
        vec3  VP;           // direction from surface to light position
        vec3 eye = -normalize(v_eyePosition);
        float spotEffect;
        float attenuation=1.0;
        vec3  halfVector;   // direction of maximum highlights
        // Compute vector from surface to light position
        VP = light.position.xyz - ecPosition3;
        spotEffect = dot(light.direction, -normalize(VP));

        if (spotEffect > light.spotCosCutoff) {
            // Compute distance between surface and light position
            d = length(VP);
            spotEffect = pow(spotEffect, light.spotExponent);
            attenuation = spotEffect / (light.constantAttenuation + light.linearAttenuation * d + light.quadraticAttenuation * d * d);

            VP = normalize(VP);
            halfVector = normalize(VP + eye);
            nDotHV = max(0.0, dot(normal, halfVector));
            nDotVP = max(0.0, dot(normal, VP));

            pf = mix(0.0, pow(nDotHV, mat_shininess), step(0.0000001, nDotVP));

            diffuse += light.diffuse.rgb * nDotVP * attenuation;
            specular += light.specular.rgb * pf * nDotVP * attenuation;

        }

        ambient += light.ambient.rgb * attenuation;

    }


    vec3 projectOnPlane(in vec3 point, in vec3 planeCenter, in vec3 planeNormal){
        return point - dot( point - planeCenter, planeNormal ) * planeNormal;
    }

    vec3 linePlaneIntersect(in vec3 lp, in vec3 lv, in vec3 pc, in vec3 pn){
       return lp+lv*(dot(pn,pc-lp)/dot(pn,lv));
    }

    void areaLight(in lightData light, in vec3 N, in vec3 V, inout vec3 ambient, inout vec3 diffuse, inout vec3 specular){
        vec3 right = light.right;
        vec3 pnormal = light.direction;
        vec3 up = light.up;

        //width and height of the area light:
        float width = light.width*0.5;
        float height = light.height*0.5;
        float attenuation;

        //project onto plane and calculate direction from center to the projection.
        vec3 projection = projectOnPlane(V,light.position.xyz,pnormal);// projection in plane
        vec3 dir = projection-light.position.xyz;

        //calculate distance from area:
        vec2 diagonal = vec2(dot(dir,right),dot(dir,up));
        vec2 nearest2D = vec2(clamp( diagonal.x,-width,width  ),clamp(  diagonal.y,-height,height));
        vec3 nearestPointInside = vec3(light.position.xyz)+(right*nearest2D.x+up*nearest2D.y);
        float dist = distance(V,nearestPointInside);//real distance to area rectangle

        vec3 lightDir = normalize(nearestPointInside - V);
        attenuation = 1.0 / (light.constantAttenuation + light.linearAttenuation * dist + light.quadraticAttenuation * dist * dist);

        float NdotL = max( dot( pnormal, -lightDir ), 0.0 );
        float NdotL2 = max( dot( N, lightDir ), 0.0 );
        if ( NdotL * NdotL2 > 0.0 ) {
            float diffuseFactor = sqrt( NdotL * NdotL2 );
            vec3 R = reflect( normalize( -V ), N );
            vec3 E = linePlaneIntersect( V, R, light.position.xyz, pnormal );
            float specAngle = dot( R, pnormal );
            if (specAngle > 0.0){
                vec3 dirSpec = E - light.position.xyz;
                vec2 dirSpec2D = vec2(dot(dirSpec,right),dot(dirSpec,up));
                vec2 nearestSpec2D = vec2(clamp( dirSpec2D.x,-width,width  ),clamp(  dirSpec2D.y,-height,height));
                float specFactor = 1.0-clamp(length(nearestSpec2D-dirSpec2D) * 0.05 * mat_shininess,0.0,1.0);
                specular += light.specular.rgb * specFactor * specAngle * diffuseFactor * attenuation;
            }
            diffuse  += light.diffuse.rgb  * diffuseFactor * attenuation;
        }
        ambient += light.ambient.rgb * attenuation;
    }


    %postFragment%
    
    
    float w(in float z, in float a){
        // z = abs(z);
        // if(z<1e-5){
        //     z = 1;
        // }
        // float accum = pow(z,3);
        // return 1/accum;
        
        
        // return pow(a, 1.0) * clamp(0.3 / (1e-5 + pow(z / 200, 4.0)), 1e-2, 3e3);
        
        // return clamp(pow(min(1.0, a * 10.0) + 0.01, 3.0) * 1e8 * pow(1.0 - z * 0.9, 3.0), 1e-2, 3e3);
        
        // return pow(abs(z), 3.0);
        
        
        // return 1.0;
        
        
        // eq 7
        // // 10/(10^-5  + (|z|/5)^2 + (|z|/200)^6)
        // float val = 10/( pow(10,-5) + pow(abs(z)/5,2) + pow(abs(z)/200,6) );
        // return a*clamp(val, pow(10,-2), 3*pow(10,3));
        
        // eq 8
        // // // 10/(10^-5  + (|z|/10)^3 + (|z|/200)^6)
        // float val = 10/( pow(10,-5) + pow(abs(z)/10,3) + pow(abs(z)/200,6) );
        // return a*clamp(val, pow(10,-2), 3*pow(10,3));
        
        // // eq 9
        // // // 0.03 /(10^-5 + (|z|/200)^4)
        // float val = 0.03/( pow(10,-5) + pow(abs(z)/200,4) );
        // return a*clamp(val, pow(10,-2), 3*pow(10,3));
        
        // // eq 10
        // // // 3*10^3 * (1-d(z))^3
        // return a*max(pow(10,-2), 3*pow(10,3)*pow(1-gl_FragCoord.z, 3));
        
        
        
        
        
        // Rendering Technology in 'Agents of Mayhem'
        // by Scott Kircher (Volition)
        // GDC 2018
        
        // https://www.gdcvault.com/play/1025233/Rendering-Technology-in-Agents-of
        // float x = min(8*a, 1) + 0.01;
        // float y = 1 - 0.95*z;
        // return min(pow(10,4.0)*pow(x,3.0)*pow(y,3.0), 300); // cap at 300
        
        // return (pow(10,4.0)*pow(y,3.0) + 5)*pow(x,3.0);
        
        
        
        
        // http://bagnell.github.io/cesium/Apps/Sandcastle/gallery/OIT.html
        return pow(a + 0.01, 4.0) + max(1e-2, min(3.0 * 1e3, 100.0 / (1e-5 + pow(abs(z) / 10.0, 3.0) + pow(abs(z) / 200.0, 6.0))));
    }
    
    
    
    void calculateLighting(in vec3 transformedNormal, inout vec3 ambient, inout vec3 diffuse, inout vec3 specular){
        
        for( int i = 0; i < num_lights; i++ ){
            if(lights[i].enabled<0.5) continue;
            if(lights[i].type<0.5){
                pointLight(lights[i], transformedNormal, v_eyePosition, ambient, diffuse, specular);
            }else if(lights[i].type<1.5){
                directionalLight(lights[i], transformedNormal, ambient, diffuse, specular);
            }else if(lights[i].type<2.5){
                spotLight(lights[i], transformedNormal, v_eyePosition, ambient, diffuse, specular);
            }else{
                areaLight(lights[i], transformedNormal, v_eyePosition, ambient, diffuse, specular);
            }
        }
    }
    
    
    // float a[5] = float[](3.4, 4.2, 5.0, 5.2, 1.1);
    vec2 poissonDisk[16] = vec2[](
        vec2(-0.94201624,  -0.39906216),
        vec2( 0.94558609,   -0.76890725),
        vec2(-0.094184101, -0.92938870),
        vec2( 0.34495938,    0.29387760),
        vec2(-0.91588581,   0.45771432),
        vec2(-0.81544232,  -0.87912464),
        vec2(-0.38277543,  0.27676845),
        vec2( 0.97484398,   0.75648379),
        vec2( 0.44323325,  -0.97511554),
        vec2( 0.53742981,  -0.47373420),
        vec2(-0.26496911, -0.41893023),
        vec2( 0.79197514,   0.19090188),
        vec2(-0.24188840,  0.99706507),
        vec2(-0.81409955,  0.91437590),
        vec2( 0.19984126,   0.78641367),
        vec2( 0.14383161,  -0.14100790)
    );
    
    
    float calculateShadow(vec4 lightSpacePosition){
        // return TEXTURE(shadow_tex, lightSpacePosition).r;
        // return TEXTURE(shadow_tex, vec2(0.5,0.5)).r;
        
        
        // // https://learnopengl.com/Advanced-Lighting/Shadows/Shadow-Mapping
        
        // // perform perspective divide
        // vec3 projCoords = lightSpacePosition.xyz / lightSpacePosition.w;
        // // transform to [0,1] range
        // projCoords = projCoords * 0.5 + 0.5;
        // // get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
        // float closestDepth = texture(shadow_map, projCoords.xy).r; 
        // // get depth of current fragment from light's perspective
        // float currentDepth = projCoords.z;
        // // check whether current frag pos is in shadow
        // float shadow = currentDepth > closestDepth  ? 1.0 : 0.0;
        // return shadow;
        
        
        
        
        // // get projected shadow value
        // vec3 tdepth = lightSpacePosition.xyz / lightSpacePosition.w;
        // vec4 depth  = vec4( tdepth.xyz, lightSpacePosition.w );
        
        // // depth.y = 1.0 - depth.y;
        // // depth.y = u_shadowHeight - depth.y;
        
        // // float shadow = 1.0;
        
        // // int numSamples = 16;
        // // float shadowDec = 1.0/float(numSamples);
        // // for( int i = 0; i < numSamples; i++ ) {
        // //     vec2 coords = depth.xy + (poissonDisk[i]/(u_shadowWidth*0.75));
        // //     float texel = texture( shadow_map, coords).r;
            
        // //     if( texel < depth.z - u_shadowBias ) {
        // //         shadow -= shadowDec * u_shadowIntensity;
        // //     }
        // // }
        // // shadow = clamp( shadow, 0.0, 1.0 );
        
        // // // are you behind the shadow view? //
        // // if( lightSpacePosition.z < 1.0) {
        // //     shadow = 1.0;
        // // }
        
        // float closestDepth = texture( shadow_map, depth.xy).r;
        // float shadow = depth.z > closestDepth  ? 1.0 : 0.0;
        
        // return shadow;
        
        
        
        
        
        // normalized space of the shadow camera, display on the environmetn
        
        float vis_min = 0.0;
        float vis_max = 1.0;
        
        vec4 post_vert_gl_pos = 
            vec4(
                v_lightSpacePosition.xyz / v_lightSpacePosition.w,
                1/v_lightSpacePosition.w
            );
        
        // --------
        
        float r = remap(-1, 1, 
                        vis_min, vis_max, 
                        post_vert_gl_pos.x);
        
        r = clip(r, vis_min, vis_max);
        
        // --------
        
        float g = remap(-1, 1, 
                        vis_min, vis_max, 
                        post_vert_gl_pos.y);
        
        g = clip(g, vis_min, vis_max);
        
        // --------
        
        float b = remap(-1, 1, 
                        vis_min, vis_max, 
                        post_vert_gl_pos.z);
        
        b = clip(b, vis_min, vis_max);
        
        // --------
        
        // (limit coloring to between the clip planes on the camera's z axis)
        if(b == 0){
            r = 0;
        }
        if(b == 0){
            g = 0;
        }
        
        
        vec3 coord = vec3(r,g,b);
        
        
        
        // modify coordinates in eye space into texture values
        float closestDepth = TEXTURE( shadow_tex, coord.xy).r;
        
        float shadow = coord.z > closestDepth ? 1.0 : 0.0;
        
        
        return shadow;
        
        // return 1.0;
        // return 0.0;
    }
    
    vec4 debugOutputShadow(){
        vec4 localColor;
        
        // vec3 tdepth = v_lightSpacePosition.xyz / v_lightSpacePosition.w;
        // vec4 depth  = vec4( tdepth.xyz, v_lightSpacePosition.w );
        
        // // show position relative to light camera
        // localColor = vec4(v_lightSpacePosition.xyz, 1.0);
        
        
        
        // // position relative to light
        // localColor = vec4(v_lightSpacePosition.x, 
        //                   v_lightSpacePosition.y,
        //                   v_lightSpacePosition.z,
        //                   1.0);
        
        // // depth from light
        // localColor = vec4(0.0, 
        //                   0.0,
        //                   -v_lightSpacePosition.z,
        //                   1.0);
        
        
        // // depth in clip space
        // localColor = vec4(remap(10.0, 150.0, 
        //                         0.0, 1.0, 
        //                         -v_lightSpacePosition.z), 
        //                   0.0,
        //                   0.0,
        //                   1.0);
        
        
        // // xy coordinate in shadow caster eye space
        // vec3 coord = vec3(v_lightSpacePosition.x+u_shadowWidth/50/2,
        //                   v_lightSpacePosition.y+u_shadowHeight/100/2,
        //                   -v_lightSpacePosition.z);
        
        // float vis_min = 0.1;
        // float vis_max = 0.9;
        
        // float r = remap(0, u_shadowWidth/50, 
        //                 vis_min, vis_max, 
        //                 coord.x);
        // r = clip(r, vis_min, vis_max);
        
        
        // float g = remap(0, u_shadowHeight/100, 
        //                 vis_min, vis_max, 
        //                 coord.y);
        // g = clip(g, vis_min, vis_max);
        
        
        // float b = remap(10.0, 150.0, 
        //                 vis_min, vis_max, 
        //                 coord.z);
        // b = clip(b, vis_min, vis_max);
        
        
        // if(r == 0){
        //     g = 0;
        // }
        // if(g == 0){
        //     r = 0;
        // }
        
        // localColor = vec4(r,g,b, 1.0);
        
        
        
        
        // // modify coordinates in eye space into texture values
        // localColor = TEXTURE( shadow_tex, vec2(r,g));
        
        
        
        
        
        
        
        
        
        
        
        // // xy in screen space
        
        
        // // NOTE: after the end of the vertex shader, OpenGL performs an additional transformation to gl_Position. This is why the coordinates in the fragment shader were not the expected normalized clip space coordinates. We need to apply that transformation here to convert MVP * pos -> expected result. 
        //     // src: https://community.khronos.org/t/please-help-gl-fragcoord-to-world-coordinates/66010
        
        // float vis_min = 0.1;
        // float vis_max = 0.9;
        
        // vec4 post_vert_gl_pos = 
        //     vec4(
        //         v_lightSpacePosition.xyz / v_lightSpacePosition.w,
        //         1/v_lightSpacePosition.w
        //     );
        
        // float r = remap(-1, 1, 
        //                 vis_min, vis_max, 
        //                 post_vert_gl_pos.x);
        
        // r = clip(r, vis_min, vis_max);
        
        // localColor = vec4(r,
        //                   0,
        //                   0,
        //                   1.0);
        
        
        
        
        
        
        // normalized space of the shadow camera, display on the environmetn
        
        float vis_min = 0.0;
        float vis_max = 1.0;
        
        vec4 post_vert_gl_pos = 
            vec4(
                v_lightSpacePosition.xyz / v_lightSpacePosition.w,
                1/v_lightSpacePosition.w
            );
        
        // --------
        
        float r = remap(-1, 1, 
                        vis_min, vis_max, 
                        post_vert_gl_pos.x);
        
        r = clip(r, vis_min, vis_max);
        
        // --------
        
        float g = remap(-1, 1, 
                        vis_min, vis_max, 
                        post_vert_gl_pos.y);
        
        g = clip(g, vis_min, vis_max);
        
        // --------
        
        float b = remap(-1, 1, 
                        vis_min, vis_max, 
                        post_vert_gl_pos.z);
        
        b = clip(b, vis_min, vis_max);
        
        // --------
        
        // (limit coloring to between the clip planes on the camera's z axis)
        if(b == 0){
            r = 0;
        }
        if(b == 0){
            g = 0;
        }
        
        
        localColor = vec4(r,g,b, 1.0);
        
        
        
        // modify coordinates in eye space into texture values
        localColor = TEXTURE( shadow_tex, vec2(r,g));
        
        
        
        
        
        
        
        return localColor;
    }
    
    
    //////////////////////////////////////////////////////
    // here's the main method
    //////////////////////////////////////////////////////


    void main (void){
        vec3 ambient = global_ambient.rgb;
        vec3 diffuse = vec3(0.0,0.0,0.0);
        vec3 specular = vec3(0.0,0.0,0.0);

		vec3 transformedNormal = normalize(v_transformedNormal);
        
        
        calculateLighting(transformedNormal, ambient, diffuse, specular);
        
        // // 
        // // without lighting
        // // 
        
        // vec4 localColor = v_diffuse;
        
        // // 
        // // with lighting
        // // 
        
        // vec4 localColor = 
        //         vec4(ambient, 1.0) * vec4(v_ambient.rgb, 0)  + 
        //         vec4(diffuse, 1.0) * v_diffuse  + 
        //         vec4(specular,1.0) * vec4(v_specular.rgb, 0) + 
        //                              vec4(v_emissive.rgb, 0);
        
        
        // 
        // with lighting and shadows
        // 
        float shadow = calculateShadow(v_lightSpacePosition);
        
        vec4 localAmbient = 
            vec4(ambient, 1.0) * vec4(v_ambient.rgb, 0);
        
        vec4 localNonAmbient = 
            vec4(diffuse, 1.0) * v_diffuse  + 
            vec4(specular,1.0) * vec4(v_specular.rgb, 0);
        
        vec4 localEmmisive = 
            vec4(v_emissive.rgb, 0);
        
        vec4 localColor = 
            localAmbient + (1.0 - shadow)*localNonAmbient + localEmmisive;
        
        
        
        
        
        
        // // 
        // // shadow value test
        // // 
        
        // vec4 localColor = debugOutputShadow();
        
        
        
        
        
        
        
        
        
        // TODO: call clamp later
        // TODO: make sure zi and ai variables get set
        
        // HDR-style : will clamp in the final compositing phase later
        
        // NOTE: get an error if you try to write to both gl_FragColor and gl_FragData
        
        // if(v_transparent_pass == 0.0){
        //     gl_FragData[0] = vec4(1,0,0, 1);
            
        // }else{
        //     gl_FragData[0] = vec4(0,1,0, 1);
            
        // }
        
        
        
        if(v_transparent_pass == 0.0){
            // --- opaque pass ---
            if(v_diffuse.a < 1){
                // ---transparent object, during opaque pass---
                discard;
                // gl_FragData[0] = vec4(localColor.rgb, 1);
            }else{
                // ---opaque object, during opaque pass---
                
                // gl_FragColor = localColor;
                // gl_FragData[0] = vec4(1,0,0, 1);
                
                gl_FragData[0] = vec4(localColor.rgb, 1.0);
            }
            
        }else{
            // --- transparent pass ---
            if(v_diffuse.a != 1){
                // ---transparent object, during transparent pass---
                // gl_FragData[0] = vec4(0,1,0, 1); // green silhouettes
                
                
                float ai = v_diffuse.a; // no alpha map, so all fragments have same alpha
                float zi = v_eyePosition.z; // relative to the camera
                
                
                // accumulation => gl_FragData[0]
                // revealage    => gl_FragData[1]
                
                gl_FragData[0] = vec4(localColor.rgb*ai, ai) * w(zi, ai);
                gl_FragData[1] = vec4(ai);
            }else{
                // ---opaque object, during transparent pass---
                // gl_FragData[0] = vec4(0,0,1, 1);
                
                discard;
            }
            
        }
        
        
    }
