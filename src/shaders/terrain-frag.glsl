#version 300 es
precision highp float;

uniform vec2 u_PlanePos; // Our location in the virtual world displayed by the plane


in vec3 fs_Pos;
in vec4 fs_Nor;
in vec4 fs_Col;
in float fs_Sine;
in vec2 fs_Uv;
in vec4 fs_shadowPos;

uniform sampler2D hightmap;
uniform sampler2D normap;
uniform sampler2D sedimap;
uniform sampler2D velmap;
uniform sampler2D fluxmap;
uniform sampler2D terrainfluxmap;
uniform sampler2D maxslippagemap;
uniform sampler2D sediBlend;
uniform sampler2D shadowMap;
uniform sampler2D sceneDepth;

#define PI 3.1415926


layout (location = 0) out vec4 out_Col; // This is the final output color that you will see on your
layout (location = 1) out vec4 col_reflect;
                  // screen for the pixel that is currently being processed.
uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform int u_TerrainDebug;
uniform int u_SedimentTrace;

uniform vec4 u_MouseWorldPos;
uniform vec3 u_MouseWorldDir;
uniform float u_BrushSize;
uniform int u_BrushType;
uniform vec2 u_BrushPos;
uniform float u_SimRes;
uniform float u_SnowRange;
uniform float u_ForestRange;
uniform int u_TerrainPlatte;
uniform vec3 unif_LightPos;


uniform mat4 u_sproj;
uniform mat4 u_sview;

vec3 calnor(vec2 uv){
    float eps = 1.f/u_SimRes;
    vec4 cur = texture(hightmap,uv);
    vec4 r = texture(hightmap,uv+vec2(eps,0.f));
    vec4 t = texture(hightmap,uv+vec2(0.f,eps));
    vec4 b = texture(hightmap,uv+vec2(0.f,-eps));
    vec4 l = texture(hightmap,uv+vec2(-eps,0.f));

    vec3 nor = vec3(l.x - r.x, 2.0, t.x - b.x);
    nor = -normalize(nor);
    return nor;
}

    #define OCTAVES 12

float random (in vec2 st) {
    return fract(sin(dot(st.xy,
    vec2(12.9898,78.233)))*
    43758.5453123);
}


float noise (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
    (c - a)* u.y * (1.0 - u.x) +
    (d - b) * u.x * u.y;
}


float fbm (in vec2 st) {
    // Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    //
    // Loop of octaves
    for (int i = 0; i < OCTAVES; i++) {
        value += amplitude * noise(st);//iqnoise(st,1.f,1.f);
        st *= 2.0;
        amplitude *= .33;
    }
    return value;
}


void main()
{
    float shadowVal = 1.0f;
    vec3 shadowCol = vec3(1.0);
    vec3 ambientCol = vec3(0.01);
    vec3 shadowMapLoc = fs_shadowPos.xyz / fs_shadowPos.w;
    shadowMapLoc = shadowMapLoc*0.5+0.5;
    float texsize = 1.0/4096.0f;
    for(int x = -1; x <= 1; ++x)
    {
        for(int y = -1; y <= 1; ++y)
        {
            float pcfDepth = texture(shadowMap, shadowMapLoc.xy + vec2(x, y) * texsize).r;
            shadowVal += shadowMapLoc.z - 0.0001 > pcfDepth ? .1 : 1.;
            shadowCol += shadowMapLoc.z - 0.0001 > pcfDepth ? vec3(0.02,0.01,0.09) : vec3(1.0);
        }
    }
    shadowVal/=9.0;
    shadowCol/=9.0;
    float shadowColorVal = texture(shadowMap, fs_Uv.xy).x;
    float sceneDepthVal = texture(sceneDepth,shadowMapLoc.xy).x;

    vec3 forestcol = vec3(63.0/255.0,155.0/255.0,7.0/255.0)*0.6;
    vec3 mtncolor = vec3(0.99,0.99,0.99);
    vec3 dirtcol = vec3(0.25,0.22,0.2);
    vec3 grass = vec3(193.0/255.0,235.0/255.0,27.0/255.0);
    vec3 sand = vec3(214.f/255.f,184.f/255.f,96.f/255.f);
    vec3 watercol = vec3(0.1,0.3,0.8);
    vec3 obsidian = vec3(0.2);

    vec3 rock1 = vec3(0.4,0.4,0.4);
    vec3 rock2 = vec3(0.2,0.2,0.2);
    vec3 rock3 = vec3(0.1,0.1,0.1);




    vec3 addcol = vec3(0.0);
    if(u_BrushType != 0){
        vec3 ro = u_MouseWorldPos.xyz;
        vec3 rd = u_MouseWorldDir;
        vec2 pointOnPlane = u_BrushPos;
        float pdis2fragment = distance(pointOnPlane, fs_Uv);
        if (pdis2fragment < 0.01 * u_BrushSize){
            float dens = (0.01 * u_BrushSize - pdis2fragment) / (0.01 * u_BrushSize);

            if(u_BrushType == 1){
                addcol = sand * 0.8;
            }else if(u_BrushType == 2){
                addcol = watercol * 0.8;
            }
            addcol *= dens;
        }

    }


    vec3 sundir = unif_LightPos;

    sundir = normalize(sundir);


    vec3 slopesin = texture(normap,fs_Uv).xyz;
    vec3 nor = -calnor(fs_Uv);

    float angle = dot(sundir,vec3(0.0,1.0,0.0));
    vec3 hue = mix(vec3(255.0,255.0,250.0)/256.0, vec3(255.0,120.0,20.0)/256.0, 1.0 - angle);




    float lamb = dot(nor,vec3(sundir.x,sundir.y,-sundir.z));


    //lamb =1.f;

    float yval = texture(hightmap,fs_Uv).x * 4.0;
    float wval = texture(hightmap,fs_Uv).y;
    float sval = texture(sediBlend, fs_Uv).x;

    vec3 finalcol = vec3(0);

    if(u_TerrainPlatte == 1){
        forestcol = mtncolor;
    }
    if(yval<=100.0){
        finalcol = forestcol;
    }else if(yval>100.0&&yval<=150.0){
        finalcol = mix(forestcol,forestcol,(yval-100.0)/50.0);
    }else if(yval>150.0){
        if(yval<600.0f ){
            finalcol = mix(forestcol, mtncolor, clamp(1.0 / pow(abs(nor.y),u_ForestRange) * (yval-150.0)/450.0, 0.0, 1.0));
        }
        else if((yval > 600.0f)){
            finalcol = mtncolor;
        }

    }




    if(abs(nor.y)<0.75){
        finalcol = mix(dirtcol,finalcol,pow(abs(nor.y)/0.75,u_SnowRange));
    }

   // finalcol = obsidian;

    //finalcol = mix(finalcol, sand, clamp( pow( sval, 3.0) * 8.0, 0.0, 4.0) );
    //finalcol = mix(finalcol,pow( sval, 1.0) * 100.0 * vec3(1.0,1.0,1.0),pow( sval,1.0) * 100.0 );

    //finalcol = vec3(clamp(sval*100.0, 0.0, 1.0));


    // sediment trace, unstable for now
    float sedimentTrace = 0.0;
    if(u_SedimentTrace == 0){
        sedimentTrace = 1.0 - pow(3.0, -sval*330.0);
        sedimentTrace *= pow(abs(nor.y), 1.0);
    }
    finalcol = mix(finalcol, vec3(214.f/255.f,214.f/255.f,96.f/255.f),clamp(2.0 * sedimentTrace, 0.0, 1.0));

    //finalcol = mix(finalcol, vec3(0.5,0.1,0.1),texture(sedimap,fs_Uv).x);

    vec3 normal = lamb*(finalcol) + ambientCol;
    vec3 fcol = normal;
    bool debug = true;
    //normal : 0, sediment : 1, velocity : 2, terrain : 3, flux : 4
    if(u_TerrainDebug == 0){
        fcol = normal;
        debug = false;
    }else if(u_TerrainDebug == 1){
        fcol = texture(sedimap,fs_Uv).xyz * 2.0;
    }else if(u_TerrainDebug == 2){
        fcol = abs(texture(velmap,fs_Uv).xyz/2.0);
        //fcol = vec3(length(texture(velmap,fs_Uv).xyz)/5.0);
        //fcol = nor1;
        //fcol.xy = fcol.xy / 2.0 + vec2(0.5);
    }else if(u_TerrainDebug == 3){
        fcol = texture(hightmap,fs_Uv).xyz;
        fcol.xy /= 200.0;
        fcol.y *= 80.0;
    }else if(u_TerrainDebug == 4){
        fcol = texture(fluxmap,fs_Uv).xyz / 3.0;
        if(fcol == vec3(0.0)){
            fcol = vec3(texture(fluxmap,fs_Uv).w)/3.0;
        }
    }else if(u_TerrainDebug == 5){
        fcol = texture(terrainfluxmap, fs_Uv).xyz * 100000.0;
    }else if(u_TerrainDebug == 6){
        fcol = texture(maxslippagemap, fs_Uv).xyz / 3.0;
    }else if(u_TerrainDebug == 7){
        fcol = vec3(sval * 100.0);
    }else if(u_TerrainDebug == 8){
        fcol = slopesin;
    }


    fcol = clamp(fcol, vec3(0.0), vec3(1.0));
    if(!debug){


        if(u_SedimentTrace == 0){
            float ssval = texture(sedimap, fs_Uv).x;
            ssval = max(min(pow(2.0 * ssval, 0.6), 1.0), 0.0);
            vec3 ss = vec3(0.8, 0.8, 0.8);
            float small = 0.1, large = 0.2;
            if (ssval <=small){
                ss = mix(ss, vec3(0.99, 0.99, 0.0), ssval/small);

            } else if (ssval > small && ssval <= large){
                ss = mix(vec3(0.99, 0.99, 0.0), vec3(0.0, 0.5, 0.99), (ssval - small)/(large - small));
            }
            else if (ssval > large){
                ss = mix(vec3(0.0, 0.5, 0.99), vec3(0.0, 0.0, 0.99), (ssval - large)/(1.0 - large));
            }
            fcol = mix(fcol, max(ss * lamb, vec3(0.0)), ssval);
        }


        fcol *= shadowCol * hue;
    }
    vec3 tmpCol = fcol;
    fcol += addcol;




    out_Col = vec4(vec3(fcol)*1.0 ,1.f);
    col_reflect = vec4(tmpCol,1.0);
    //out_Col = vec4(vec3(shadowColorVal),1.0);
}
