Shader "Hidden/CloudRaymarcher"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 viewVector : TEXCOORD1;
            };

            float3 _ContainerMin;
            float3 _ContainerMax;
            float3 _NoiseScale;
            float3 _NoiseOffset;
            float3 _PerlinScale;
            float3 _PerlinOffset;
            float3 _LightColor;
            float4 _PhaseParams;

            float _DensityBias;
            float _DensityMultiplier;
            float _PerlinBias;
            float _PerlinMultiplier;
            float _StepSize;
            float _DarknessThreshold;
            float _LightAbsorption; 
            float _BeerPowderScaler;
            float _BeerPowderPower;
            float _BlueNoiseStrength;
            float _RainAbsorption;

            float _DensityFadeOffDistance;
            
            int _NumLightSteps;

            sampler3D _NoiseTexture;
            sampler2D _MainTex;
            sampler2D _CameraDepthTexture;
            sampler2D _BlueNoise;
            sampler2D _PerlinNoise;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                float3 viewVectorCamera = mul(
                    unity_CameraInvProjection,
                    float4(o.uv * 2. - 1., 0.0f, -1.0f)).xyz;
                o.viewVector = mul(unity_CameraToWorld, float4(viewVectorCamera, 0.0f)).xyz;
                return o;
            }

            float3 vecToLight(float3 lightPos, float3 samplePos) {
                return lightPos - samplePos;
            }

            float distToLight(float3 lightPos, float3 samplePos) {
                return length(vecToLight(lightPos, samplePos));
            }

            float3 dirToLight(float3 lightPos, float3 samplePos) {
                return normalize(vecToLight(lightPos, samplePos));
            }

            float3 getLightIntensity(float3 lightPos, float3 lightIntensity, float lightAttenuation, float3 samplePos) {
                return lightIntensity / (lightAttenuation * pow(distToLight(lightPos, samplePos), 2));
            }

            // Returns (dstToBox, dstInsideBox). If ray misses box, dstInsideBox will be zero
            float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 invRaydir) {
                // Adapted from: http://jcgt.org/published/0007/03/04/
                float3 t0 = (boundsMin - rayOrigin) * invRaydir;
                float3 t1 = (boundsMax - rayOrigin) * invRaydir;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);
                
                float dstA = max(max(tmin.x, tmin.y), tmin.z);
                float dstB = min(tmax.x, min(tmax.y, tmax.z));

                // CASE 1: ray intersects box from outside (0 <= dstA <= dstB)
                // dstA is dst to nearest intersection, dstB dst to far intersection

                // CASE 2: ray intersects box from inside (dstA < 0 < dstB)
                // dstA is the dst to intersection behind the ray, dstB is dst to forward intersection

                // CASE 3: ray misses box (dstA > dstB)

                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }
            float snoise(float3 v);
            float sampleDensity(float3 samplePoint){
                // float3 p = round(frac(samplePoint * .5));
                // return p.x*p.y*p.z;
                float3 densityTx = tex3D(_NoiseTexture, (samplePoint*_NoiseScale) + _NoiseOffset);
                float rawDensity = (1 - densityTx.r) - _DensityBias;
                float3
                    minDist = saturate((samplePoint - _ContainerMin)/_DensityFadeOffDistance),
                    maxDist = saturate((_ContainerMax - samplePoint)/_DensityFadeOffDistance);
                float fadeOut = saturate(
                    min(
                        min(minDist.x, min(minDist.y, minDist.z)),
                        min(maxDist.x, min(maxDist.y, maxDist.z))
                    ));

                // tex3D(_NoiseTexture, (samplePoint + _PerlinOffset) * _PerlinScale).g
                float perlin = snoise((samplePoint + _PerlinOffset)) * 2. - 1. - _PerlinBias;
                rawDensity += perlin * _PerlinMultiplier;
                
                return rawDensity * fadeOut;
            }

            float beerPowder(float density) {
                return _BeerPowderScaler * exp(-density * _BeerPowderPower * _RainAbsorption) * (1 - exp(-density * 2 * _BeerPowderPower));
            }

            float calcLight(float3 samplePos) {
                float3 dirToLight = _WorldSpaceLightPos0.xyz;
                float dstInsideBox = rayBoxDst(_ContainerMin, _ContainerMax, samplePos, 1 / dirToLight).y;

                float stepSize = dstInsideBox / _NumLightSteps;
                float totalDensity = 0;

                float3 current_pos = samplePos;
                [loop]
                for (int i = 0; i < _NumLightSteps; i++) {
                    current_pos += stepSize * dirToLight;
                    totalDensity += max(0, sampleDensity(current_pos) * stepSize);
                }

                float transmittance = beerPowder(totalDensity * _LightAbsorption); //beerPowder(totalDensity)
                return _DarknessThreshold + transmittance * (1 - _DarknessThreshold);
            }

            //// Henyey-Greenstein
            float hg(float cosAngle, float g) {
               float g2 = g * g;
               return (1 - g2) / (4 * 3.1415 * pow(1 + g2 - 2 * g * cosAngle, 1.5));
            }

            float phase(float a) {
               float blend = .5;
               float hgBlend = hg(a, _PhaseParams.x) * (1 - blend) + hg(a, -_PhaseParams.y) * blend;
               return _PhaseParams.z + hgBlend * _PhaseParams.w;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                const float sampleWeight = _StepSize;


                fixed4 col = tex2D(_MainTex, i.uv);
                const float3 rayOrigin = mul(unity_CameraToWorld, float4(0, 0, 0, 1));
                const float3 rayDir = normalize(i.viewVector);

                float cosAngle = dot(rayDir, _WorldSpaceLightPos0.xyz);
                float phaseVal = phase(cosAngle);

                float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv)) * length(i.viewVector);

                const float2 intersection = rayBoxDst(_ContainerMin, _ContainerMax, rayOrigin, 1/rayDir);
                const float dstToBox = intersection.x;
                const float dstInsideBox = min(intersection.y, depth-dstToBox);
                if(dstInsideBox > 0) {
                    float randomOffset = tex2D(_BlueNoise, i.uv + _Time) * _BlueNoiseStrength;
                    float3 samplePos = rayOrigin + rayDir * dstToBox;
                    float distanceMarched = randomOffset;
                    float transmittance = 1;
                    float3 light_val = 0;
                    [loop]
                    while(distanceMarched < dstInsideBox){
                        float temp_density = sampleDensity(samplePos);
                        if (temp_density > 0) { //Ray travels into clouds
                            float light_transmittance = calcLight(samplePos);
                            light_val += transmittance * light_transmittance * temp_density * _StepSize * phaseVal;
                            float sampleMass = temp_density *_StepSize * _DensityMultiplier;
                            float beersTransmittance = exp(-sampleMass);
                            transmittance *= beersTransmittance;//(beersTransmittance * powderTransmittance);
                            if (transmittance < 0.01) {
                                break;
                            }
                            //density += length(getLightIntensity(_WorldSpaceLightPos0.xyz, _LightColor0.rgb, 1, samplePos));
                        }
                        samplePos += rayDir * _StepSize;
                        distanceMarched += _StepSize;
                    }
                    float3 backgroundCol = tex2D(_MainTex, i.uv);
                    float3 cloudCol = _LightColor * light_val;
                    col = float4(backgroundCol * transmittance + cloudCol,0);
                }
                
                return col;
            }

            /*
            Description:
                Array- and textureless CgFx/HLSL 2D, 3D and 4D simplex noise functions.
                a.k.a. simplified and optimized Perlin noise.
                
                The functions have very good performance
                and no dependencies on external data.
                
                2D - Very fast, very compact code.
                3D - Fast, compact code.
                4D - Reasonably fast, reasonably compact code.
            ------------------------------------------------------------------
            Ported by:
                Lex-DRL
                I've ported the code from GLSL to CgFx/HLSL for Unity,
                added a couple more optimisations (to speed it up even further)
                and slightly reformatted the code to make it more readable.
            Original GLSL functions:
                https://github.com/ashima/webgl-noise
                Credits from original glsl file are at the end of this cginc.
            ------------------------------------------------------------------
            Usage:
                
                float ns = snoise(v);
                // v is any of: float2, float3, float4
                
                Return type is float.
                To generate 2 or more components of noise (colorful noise),
                call these functions several times with different
                constant offsets for the arguments.
                E.g.:
                
                float3 colorNs = float3(
                    snoise(v),
                    snoise(v + 17.0),
                    snoise(v - 43.0),
                );
            Remark about those offsets from the original author:
                
                People have different opinions on whether these offsets should be integers
                for the classic noise functions to match the spacing of the zeroes,
                so we have left that for you to decide for yourself.
                For most applications, the exact offsets don't really matter as long
                as they are not too small or too close to the noise lattice period
                (289 in this implementation).
            */

            // 1 / 289
            #define NOISE_SIMPLEX_1_DIV_289 0.00346020761245674740484429065744f

            float mod289(float x) {
                return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
            }

            float2 mod289(float2 x) {
                return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
            }

            float3 mod289(float3 x) {
                return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
            }

            float4 mod289(float4 x) {
                return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
            }


            // ( x*34.0 + 1.0 )*x = 
            // x*x*34.0 + x
            float permute(float x) {
                return mod289(
                    x*x*34.0 + x
                );
            }

            float3 permute(float3 x) {
                return mod289(
                    x*x*34.0 + x
                );
            }

            float4 permute(float4 x) {
                return mod289(
                    x*x*34.0 + x
                );
            }



            float4 grad4(float j, float4 ip)
            {
                const float4 ones = float4(1.0, 1.0, 1.0, -1.0);
                float4 p, s;
                p.xyz = floor( frac(j * ip.xyz) * 7.0) * ip.z - 1.0;
                p.w = 1.5 - dot( abs(p.xyz), ones.xyz );
                
                // GLSL: lessThan(x, y) = x < y
                // HLSL: 1 - step(y, x) = x < y
                p.xyz -= sign(p.xyz) * (p.w < 0);
                
                return p;
            }
            // ----------------------------------- 3D -------------------------------------

            float snoise(float3 v)
            {
                const float2 C = float2(
                    0.166666666666666667, // 1/6
                    0.333333333333333333  // 1/3
                );
                const float4 D = float4(0.0, 0.5, 1.0, 2.0);
                
            // First corner
                float3 i = floor( v + dot(v, C.yyy) );
                float3 x0 = v - i + dot(i, C.xxx);
                
            // Other corners
                float3 g = step(x0.yzx, x0.xyz);
                float3 l = 1 - g;
                float3 i1 = min(g.xyz, l.zxy);
                float3 i2 = max(g.xyz, l.zxy);
                
                float3 x1 = x0 - i1 + C.xxx;
                float3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
                float3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y
                
            // Permutations
                i = mod289(i);
                float4 p = permute(
                    permute(
                        permute(
                                i.z + float4(0.0, i1.z, i2.z, 1.0 )
                        ) + i.y + float4(0.0, i1.y, i2.y, 1.0 )
                    ) 	+ i.x + float4(0.0, i1.x, i2.x, 1.0 )
                );
                
            // Gradients: 7x7 points over a square, mapped onto an octahedron.
            // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
                float n_ = 0.142857142857; // 1/7
                float3 ns = n_ * D.wyz - D.xzx;
                
                float4 j = p - 49.0 * floor(p * ns.z * ns.z); // mod(p,7*7)
                
                float4 x_ = floor(j * ns.z);
                float4 y_ = floor(j - 7.0 * x_ ); // mod(j,N)
                
                float4 x = x_ *ns.x + ns.yyyy;
                float4 y = y_ *ns.x + ns.yyyy;
                float4 h = 1.0 - abs(x) - abs(y);
                
                float4 b0 = float4( x.xy, y.xy );
                float4 b1 = float4( x.zw, y.zw );
                
                //float4 s0 = float4(lessThan(b0,0.0))*2.0 - 1.0;
                //float4 s1 = float4(lessThan(b1,0.0))*2.0 - 1.0;
                float4 s0 = floor(b0)*2.0 + 1.0;
                float4 s1 = floor(b1)*2.0 + 1.0;
                float4 sh = -step(h, 0.0);
                
                float4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
                float4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;
                
                float3 p0 = float3(a0.xy,h.x);
                float3 p1 = float3(a0.zw,h.y);
                float3 p2 = float3(a1.xy,h.z);
                float3 p3 = float3(a1.zw,h.w);
                
            //Normalise gradients
                float4 norm = rsqrt(float4(
                    dot(p0, p0),
                    dot(p1, p1),
                    dot(p2, p2),
                    dot(p3, p3)
                ));
                p0 *= norm.x;
                p1 *= norm.y;
                p2 *= norm.z;
                p3 *= norm.w;
                
            // Mix final noise value
                float4 m = max(
                    0.6 - float4(
                        dot(x0, x0),
                        dot(x1, x1),
                        dot(x2, x2),
                        dot(x3, x3)
                    ),
                    0.0
                );
                m = m * m;
                return 42.0 * dot(
                    m*m,
                    float4(
                        dot(p0, x0),
                        dot(p1, x1),
                        dot(p2, x2),
                        dot(p3, x3)
                    )
                );
            }


            //                 Credits from source glsl file:
            //
            // Description : Array and textureless GLSL 2D/3D/4D simplex 
            //               noise functions.
            //      Author : Ian McEwan, Ashima Arts.
            //  Maintainer : ijm
            //     Lastmod : 20110822 (ijm)
            //     License : Copyright (C) 2011 Ashima Arts. All rights reserved.
            //               Distributed under the MIT License. See LICENSE file.
            //               https://github.com/ashima/webgl-noise
            //
            //
            //           The text from LICENSE file:
            //
            //
            // Copyright (C) 2011 by Ashima Arts (Simplex noise)
            // Copyright (C) 2011 by Stefan Gustavson (Classic noise)
            // 
            // Permission is hereby granted, free of charge, to any person obtaining a copy
            // of this software and associated documentation files (the "Software"), to deal
            // in the Software without restriction, including without limitation the rights
            // to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
            // copies of the Software, and to permit persons to whom the Software is
            // furnished to do so, subject to the following conditions:
            // 
            // The above copyright notice and this permission notice shall be included in
            // all copies or substantial portions of the Software.
            // 
            // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
            // IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
            // FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
            // AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
            // LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
            // OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
            // THE SOFTWARE.
            ENDCG

            

        }
    }
}
