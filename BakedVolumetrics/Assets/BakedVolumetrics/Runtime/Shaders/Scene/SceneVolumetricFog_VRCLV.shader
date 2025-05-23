// Upgrade NOTE: upgraded instancing buffer 'InstanceProperties' to new syntax.

//References
//UnityCG.cginc - https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityCG.cginc
//UnityShaderVariables.cginc - https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityShaderVariables.cginc

// Original shader by frostbone25 (https://github.com/frostbone25/Unity-Baked-Volumetrics) 
// Edited by ikeiwa for VRC Light Volumes

Shader "BakedVolumetrics/SceneVolumetricFog_VRCLV"
{
    Properties
    {
        [Header(Volume)]
        _VolumeSize("Volume World Size", Vector) = (0, 0, 0, 0)

        [Header(Density)]
        [Toggle(_USE_DENSITY_TEXTURE)] _UseDensityTexture("Use Density Texture", Float) = 0
        _DensityVolumeTexture("Density Texture", 3D) = "white" {}
        _DensityTiling("Density Texture Tiling", Vector) = (0.25,0.25,0.25,0)
        _DensityScrolling("Density Texture Scrolling", Vector) = (0,0.1,0,0)
        _DensityPower("Density Texture Intensity", Float) = 1

        [Header(Rendering)]
        [KeywordEnum(_8, _16, _24, _32, _48, _64, _128)] _Samples("Samples", Float) = 3
        _RaymarchStepSize("Raymarch Step Size", Float) = 25
        [Toggle(_HALF_RESOLUTION)] _HalfResolution("Half Resolution", Float) = 0
        [Toggle(_TERMINATE_RAYS_OUTSIDE_VOLUME)] _TerminateRaysOutsideVolume("Terminate Rays Outside Volume", Float) = 1
        [Toggle(_KEEP_RAYS_ONLY_IN_VOLUME)] _RaysOnlyInVolume("Trace Rays Only In Volume", Float) = 1
        [Toggle(_ANIMATED_NOISE)] _EnableAnimatedJitter("Animated Noise", Float) = 0
        _JitterTexture("Jitter Texture", 2D) = "white" {}
        _JitterStrength("Jitter Strength", Float) = 2

        [Header(Lighting Settings)]
        _LightIntensity("Lights Intensity", Float) = 1
        _LightThreshold("Lights Threshold", Float) = 0
        
        [Header(Advanced Settings)]
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Int) = 1 //(0 = Default | 1 = Front | 2 = Back)
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc ("Blend mode Source", Int) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend mode Destination", Int) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent+2000"
        }

        Cull [_CullMode]
        ZWrite Off
        ZTest Off
        Blend [_BlendSrc] [_BlendDst]

        Pass
        {
            CGPROGRAM
            #pragma vertex vertex_base
            #pragma fragment fragment_base

            //||||||||||||||||||||||||||||| INCLUDES |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| INCLUDES |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| INCLUDES |||||||||||||||||||||||||||||

            //Unity3d
            #include "UnityCG.cginc"
            #include "Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc"

            //Custom (From Pema)
            #include "QuadIntrinsics.cginc"

            //||||||||||||||||||||||||||||| KEYWORDS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| KEYWORDS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| KEYWORDS |||||||||||||||||||||||||||||

            //Unity3d
            #pragma multi_compile_instancing
            #pragma multi_compile _ UNITY_LIGHT_PROBE_PROXY_VOLUME

            //Custom
            #pragma multi_compile _SAMPLES__8 _SAMPLES__16 _SAMPLES__24 _SAMPLES__32 _SAMPLES__48 _SAMPLES__64 _SAMPLES__128

            #pragma shader_feature_local _ANIMATED_NOISE
            #pragma shader_feature_local _HALF_RESOLUTION
            #pragma shader_feature_local _TERMINATE_RAYS_OUTSIDE_VOLUME
            #pragma shader_feature_local _KEEP_RAYS_ONLY_IN_VOLUME
            #pragma shader_feature_local _USE_DENSITY_TEXTURE

            //NOTE: IF MIP QUAD OPTIMIZATION IS ENABLED
            //WE HAVE TO TARGET 5.0
            #if defined (_HALF_RESOLUTION)
                //#pragma target 5.0
                //#pragma require interpolators10
                //#pragma require interpolators15
                //#pragma require interpolators32
                //#pragma require mrt4
                //#pragma require mrt8
                #pragma require derivatives
                //#pragma require samplelod
                //#pragma require fragcoord
                //#pragma require integers
                //#pragma require 2darray
                #pragma require cubearray
                //#pragma require instancing
                //#pragma require geometry
                //#pragma require compute
                //#pragma require randomwrite
                //#pragma require tesshw
                //#pragma require tessellation
                //#pragma require msaatex
                //#pragma require sparsetex
                //#pragma require framebufferfetch
            #endif

            //||||||||||||||||||||||||||||| MACROS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| MACROS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| MACROS |||||||||||||||||||||||||||||

            //#define UseInstancedProps

            #ifdef _SAMPLES__8
            #define RAYMARCH_STEPS 8
            #elif _SAMPLES__16
                #define RAYMARCH_STEPS 16
            #elif _SAMPLES__24
                #define RAYMARCH_STEPS 24
            #elif _SAMPLES__32
                #define RAYMARCH_STEPS 32
            #elif _SAMPLES__48
                #define RAYMARCH_STEPS 48
            #elif _SAMPLES__64
                #define RAYMARCH_STEPS 64
            #elif _SAMPLES__128
                #define RAYMARCH_STEPS 128
            #else
                #define RAYMARCH_STEPS 32
            #endif

            //||||||||||||||||||||||||||||| SHADER PARAMETERS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| SHADER PARAMETERS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| SHADER PARAMETERS |||||||||||||||||||||||||||||

            UNITY_INSTANCING_BUFFER_START(InstanceProperties)
                UNITY_DEFINE_INSTANCED_PROP(float3, _VolumeSize)
            UNITY_INSTANCING_BUFFER_END(InstanceProperties)
            
            fixed _RaymarchStepSize;
            fixed _JitterStrength;

            fixed4 _JitterTexture_TexelSize;
            fixed4 _CameraDepthTexture_TexelSize;

            float _LightIntensity;
            float _LightThreshold;

            sampler2D_half _JitterTexture;

            sampler3D _DensityVolumeTexture;
            fixed3 _DensityTiling;
            fixed3 _DensityScrolling;
            float _DensityPower;

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_CameraDepthTexture);

            //||||||||||||||||||||||||||||| METHODS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| METHODS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| METHODS |||||||||||||||||||||||||||||

            #if defined (_ANIMATED_NOISE)
                //animated noise courtesy of silent
                fixed r2sequence(fixed2 pixel)
                {
                    const fixed a1 = 0.75487766624669276;
                    const fixed a2 = 0.569840290998;

                    return frac(a1 * fixed(pixel.x) + a2 * fixed(pixel.y));
                }

                fixed2 r2_modified(fixed idx, fixed2 seed)
                {
                    return frac(seed + fixed(idx) * fixed2(0.245122333753, 0.430159709002));
                }

                fixed noise(fixed2 uv)
                {
                    //uv += r2_modified(_Time.y, uv);
                    uv += fixed2(_Time.y, _Time.y);
                    uv *= _ScreenParams.xy * _JitterTexture_TexelSize.xy;

                    return tex2Dlod(_JitterTexture, fixed4(uv, 0, 0));
                }
            #else
            fixed noise(fixed2 uv)
            {
                #if defined (_HALF_RESOLUTION)
                        return tex2Dlod(_JitterTexture, fixed4(uv * _ScreenParams.xy * _JitterTexture_TexelSize.xy * 0.5, 0, 0));
                #else
                return tex2Dlod(_JitterTexture, fixed4(uv * _ScreenParams.xy * _JitterTexture_TexelSize.xy, 0, 0));
                #endif
            }
            #endif

            //||||||||||||||||||||||||||||| MESH DATA STRUCT |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| MESH DATA STRUCT |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| MESH DATA STRUCT |||||||||||||||||||||||||||||

            struct meshData
            {
                fixed4 vertex : POSITION; //Vertex Position (X = Position X | Y = Position Y | Z = Position Z | W = 1)

                //Single Pass Instanced Support
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            //||||||||||||||||||||||||||||| VERTEX TO FRAGMENT STRUCT |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| VERTEX TO FRAGMENT STRUCT |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| VERTEX TO FRAGMENT STRUCT |||||||||||||||||||||||||||||

            struct vertexToFragment
            {
                fixed4 vertexCameraClipPosition : SV_POSITION; //Vertex Position In Camera Clip Space
                fixed4 screenPosition : TEXCOORD0; //Screen Position
                fixed3 cameraRelativeWorldPosition : TEXCOORD1;

                //Single Pass Instanced Support
                UNITY_VERTEX_OUTPUT_STEREO
            };

            //||||||||||||||||||||||||||||| VERTEX FUNCTION |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| VERTEX FUNCTION |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| VERTEX FUNCTION |||||||||||||||||||||||||||||

            vertexToFragment vertex_base(meshData data)
            {
                vertexToFragment vertex;

                //Single Pass Instanced Support
                UNITY_SETUP_INSTANCE_ID(data);
                UNITY_INITIALIZE_OUTPUT(vertexToFragment, vertex);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(vertex);

                vertex.vertexCameraClipPosition = UnityObjectToClipPos(data.vertex);
                vertex.screenPosition = ComputeScreenPos(vertex.vertexCameraClipPosition);
                vertex.cameraRelativeWorldPosition = mul(unity_ObjectToWorld, fixed4(data.vertex.xyz, 1.0)).xyz -
                    _WorldSpaceCameraPos;

                return vertex;
            }

            //||||||||||||||||||||||||||||| FRAGMENT FUNCTION |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| FRAGMENT FUNCTION |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| FRAGMENT FUNCTION |||||||||||||||||||||||||||||

            fixed4 fragment_base(vertexToFragment vertex) : SV_Target
            {
                //Single Pass Instanced Support
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(vertex);

                #if defined (_HALF_RESOLUTION)
                    SETUP_QUAD_INTRINSICS(vertex.vertexCameraClipPosition)
                #endif

                //our final computed fog color
                fixed4 result = fixed4(0, 0, 0, 0); //rgb = fog color, a = transmittance

                #if defined (_HALF_RESOLUTION)
                    if (QuadGetLaneID() == 0)
                    {
                #endif

                //get our screen uv coords
                fixed2 screenUV = vertex.screenPosition.xy / vertex.screenPosition.w;

                #if UNITY_UV_STARTS_AT_TOP
                if (_CameraDepthTexture_TexelSize.y < 0)
                    screenUV.y = 1 - screenUV.y;
                #endif

                #if UNITY_SINGLE_PASS_STEREO
                    // If Single-Pass Stereo mode is active, transform the
                    // coordinates to get the correct output UV for the current eye.
                    fixed4 scaleOffset = unity_StereoScaleOffset[unity_StereoEyeIndex];
                    screenUV = (screenUV - scaleOffset.zw) / scaleOffset.xy;
                #endif

                //draw our scene depth texture and linearize it
                fixed linearDepth = LinearEyeDepth(
                    SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(vertex.screenPosition)));

                //calculate the world position view plane for the camera
                fixed3 cameraWorldPositionViewPlane = vertex.cameraRelativeWorldPosition.xyz / dot(
                    vertex.cameraRelativeWorldPosition.xyz, unity_WorldToCamera._m20_m21_m22);

                //get the world position vector
                fixed3 worldPos = cameraWorldPositionViewPlane * linearDepth + _WorldSpaceCameraPos;

                // UV offset by orientation
                fixed3 localViewDir = normalize(cameraWorldPositionViewPlane);

                //compute jitter
                fixed jitter = 1.0f + noise(screenUV + length(localViewDir)) * _RaymarchStepSize * _JitterStrength;

                #if defined (_HALF_RESOLUTION)
                    jitter *= 2.0f;
                #endif

                //get our ray increment vector that we use so we can march into the scene. Jitter it also so we can mitigate banding/stepping artifacts
                fixed3 raymarch_rayIncrement = normalize(vertex.cameraRelativeWorldPosition.xyz) / RAYMARCH_STEPS;

                //get the length of the step
                fixed stepLength = length(raymarch_rayIncrement);

                fixed3 halfVolumeSize = UNITY_ACCESS_INSTANCED_PROP(InstanceProperties, _VolumeSize) * 0.5;

                //get our starting ray position from the camera
                fixed3 raymarch_currentPos = _WorldSpaceCameraPos + raymarch_rayIncrement * jitter;
                float3 volumePos = unity_ObjectToWorld._m03_m13_m23;        

                //start marching
                for (int i = 0; i < RAYMARCH_STEPS; i++)
                {
                    //get the distances of the ray and the world position
                    float raymarchRayDistance = distance(_WorldSpaceCameraPos, raymarch_currentPos);
                    float sceneRayDistance = distance(_WorldSpaceCameraPos, worldPos);

                    //IMPORTANT: Check the current position distance of our ray compared to where we started.
                    //If our distance is less than that of the world then that means we aren't intersecting into any objects yet so keep accumulating.
                    bool isRayPositionIntersectingScene = raymarchRayDistance < sceneRayDistance;

                    #if defined(_KEEP_RAYS_ONLY_IN_VOLUME)
                        //make sure we are within our little box
                        bool isInBox = all(abs(raymarch_currentPos - volumePos) < halfVolumeSize);

                        if (isRayPositionIntersectingScene && isInBox)
                    #else
                    if (isRayPositionIntersectingScene)
                    #endif
                    {
                        //And also keep going if we haven't reached the fullest density just yet.
                        if (result.a < 1.0f)
                        {
                            //sample the fog color (rgb = color, a = density)

                            //The SH coefficients textures and probe occlusion are packed into 1 atlas.
                            //-------------------------
                            //| ShR | ShG | ShB | Occ |
                            //-------------------------

                            // sampler state comes from SHr (all SH textures share the same sampler)

                            float3 sphericalHarmonics_0;
                            float3 sphericalHarmonics_A_R;
                            float3 sphericalHarmonics_A_G;
                            float3 sphericalHarmonics_A_B;
                            LightVolumeSH(raymarch_currentPos, sphericalHarmonics_0, sphericalHarmonics_A_R,
                                      sphericalHarmonics_A_G, sphericalHarmonics_A_B);

                            float3 sampledColor = max(0.0, sphericalHarmonics_0 * _LightIntensity - _LightThreshold);

                            #if defined (_USE_DENSITY_TEXTURE)
                            float alpha = tex3Dlod(_DensityVolumeTexture, fixed4(raymarch_currentPos*_DensityTiling+(_DensityScrolling*_Time.y), 0)).r;
                            alpha = pow(alpha,_DensityPower);

                            result += fixed4(sampledColor.rgb * alpha, 1.0) * stepLength; //this is slightly cheaper                 
                            #else
                            result += fixed4(sampledColor.rgb, 1.0) * stepLength;
                            //this is slightly cheaper                 
                            #endif
                        }
                        else
                            break; //terminante the ray 
                    }
                    #if defined(_TERMINATE_RAYS_OUTSIDE_VOLUME)
                        else
                            break; //terminate the ray
                    #endif

                    //keep stepping forward into the scene
                    raymarch_currentPos += raymarch_rayIncrement * _RaymarchStepSize;
                }

                //clamp the alpha channel otherwise we get blending issues with bright spots
                result.a = clamp(result.a, 0.0f, 1.0f);

                #if defined (_HALF_RESOLUTION)
                    }
                    return QuadReadLaneAt(result, uint2(0, 0));
                #endif

                //return the final fog color
                return result;
            }
            ENDCG
        }
    }
}