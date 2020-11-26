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
            
            float _StepSize;

            float3 _ContainerMin;
            float3 _ContainerMax;
            float3 _NoiseScale;

            float _DensityBias;
            sampler3D _NoiseTexture;
            // Texture3D<float3> _NoiseTexture;
            // SamplerState samplerNoiseTexture;

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
                return max((1 - tex3D(_NoiseTexture, samplePoint*_NoiseScale)) - _DensityBias, 0);
                // return _NoiseTexture.SampleLevel(samplerNoiseTexture, samplePoint, 0);
            }

            sampler2D _MainTex;
            sampler2D _CameraDepthTexture;

            fixed4 frag (v2f i) : SV_Target
            {
                const float sampleWeight = _StepSize;

                fixed4 col = tex2D(_MainTex, i.uv);
                const float3 rayOrigin = mul(unity_CameraToWorld, float4(0, 0, 0, 1));
                const float3 rayDir = normalize(i.viewVector);

                const float2 intersection = rayBoxDst(_ContainerMin, _ContainerMax, rayOrigin, 1/rayDir);
                const float dstToBox = intersection.x;
                const float dstInsideBox = intersection.y;
                if(dstInsideBox != 0) {
                    float3 samplePos = rayOrigin + rayDir * dstToBox;
                    float distanceMarched = 0;
                    float density = 0;
                    [loop]
                    while(distanceMarched < dstInsideBox){
                        density += sampleDensity(samplePos) * _StepSize;

                        samplePos += rayDir * _StepSize;
                        distanceMarched += _StepSize;
                    }

                    col.rgb = lerp(float3(.9, .9, 1), col.rgb, exp(-density));
                }
                
                // return LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv)) * length(i.viewVector);
                return col;
            }
            ENDCG

            

        }
    }
}
