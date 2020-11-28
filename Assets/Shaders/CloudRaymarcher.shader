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
            float3 _LightColor;
            float4 _PhaseParams;

            float _DensityBias;
            float _DensityMultiplier;
            float _StepSize;
            float _DarknessThreshold;
            float _LightAbsorption; 
            
            int _NumLightSteps;

            sampler3D _NoiseTexture;
            sampler2D _MainTex;
            sampler2D _CameraDepthTexture;

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

            float sampleDensity(float3 samplePoint){
                // float3 p = round(frac(samplePoint * .5));
                // return p.x*p.y*p.z;
                return (1 - tex3D(_NoiseTexture, (samplePoint*_NoiseScale) + _NoiseOffset)) - _DensityBias;
                // return _NoiseTexture.SampleLevel(samplerNoiseTexture, samplePoint, 0);
            }

            float beerPowder(float density) {
                return 2 * exp(-density) * (1 - exp(-density * 2));
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

                float transmittance = exp(-totalDensity * _LightAbsorption); //beerPowder(totalDensity)
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


                //TODO: User z buffer to draw stuff correctly
                const float2 intersection = rayBoxDst(_ContainerMin, _ContainerMax, rayOrigin, 1/rayDir);
                const float dstToBox = intersection.x;
                const float dstInsideBox = intersection.y;
                if(dstInsideBox != 0) {
                    float3 samplePos = rayOrigin + rayDir * dstToBox;
                    float distanceMarched = 0;
                    float transmittance = 1;
                    float powderTransmittance = 1.;
                    //float density = 0;
                    float3 light_val = 0;
                    float totalMass = 0;
                    [loop]
                    while(distanceMarched < dstInsideBox){
                        float temp_density = sampleDensity(samplePos);
                        if (temp_density > 0) { //Ray travels into clouds
                            float light_transmittance = calcLight(samplePos);
                            light_val += transmittance * light_transmittance * temp_density * _StepSize * phaseVal;
                            float sampleMass = temp_density *_StepSize * _DensityMultiplier;
                            totalMass += sampleMass;
                            float beersTransmittance = exp(-sampleMass);
                            float powderTransmittance = 1. - exp(-2 * temp_density * _StepSize * _DensityMultiplier);
                            transmittance *= 1. - (beersTransmittance * powderTransmittance);
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
                    float totalTransmittance = transmittance;//transmittance * 2 * (1.- powderTransmittance);
                    // if(totalTransmittance < .01) totalTransmittance
                    col = float4(backgroundCol * totalTransmittance + cloudCol,0);
                    //col.rgb = lerp(float3(.9, .9, 1), col.rgb, exp(-density));
                }
                
                // return LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv)) * length(i.viewVector);
                return col;
            }
            ENDCG

            

        }
    }
}
