#ifndef CUSTOM_VRC_LIGHT_VOLUMES_INCLUDED
#define CUSTOM_VRC_LIGHT_VOLUMES_INCLUDED

// Samples 3 SH textures and packing them into L1 channels
void LV_SampleLightVolumeTexL0(float3 uvw0, float3 uvw1, float3 uvw2, out float3 L0) {
    // Sampling 3D Atlas
    float4 tex0 = tex3Dlod(_UdonLightVolume, float4(uvw0, 0));
    // Packing final data
    L0 = tex0.rgb;
}

// Samples a Volume with ID and Local UVW
void LV_SampleVolumeL0(uint id, float3 localUVW, out float3 L0) {
    
    // Additive UVW
    float3 uvw0 = LV_LocalToIsland(id, 0, localUVW);
    float3 uvw1 = LV_LocalToIsland(id, 1, localUVW);
    float3 uvw2 = LV_LocalToIsland(id, 2, localUVW);
                
    // Sample additive
    LV_SampleLightVolumeTexL0(uvw0, uvw1, uvw2, L0);
    
    // Color correction
    float4 color = _UdonLightVolumeColor[id];
    L0 = L0 * color.rgb;        
}

// Calculates SH components based on the world position
void LightVolumeSHL0(float3 worldPos, out float3 L0) {

    // Initializing output variables
    L0  = float3(0, 0, 0);
    
    // Fallback to default light probes if Light Volume are not enabled
    if (!_UdonLightVolumeEnabled || _UdonLightVolumeCount == 0) {
        L0 = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
        return;
    }
    
    uint volumeID_A = -1; // Main, dominant volume ID
    uint volumeID_B = -1; // Secondary volume ID to blend main with

    float3 localUVW   = float3(0, 0, 0); // Last local UVW to use in disabled Light Probes mode
    float3 localUVW_A = float3(0, 0, 0); // Main local UVW for Y Axis and Free rotations
    float3 localUVW_B = float3(0, 0, 0); // Secondary local UVW
    
    // Are A and B volumes NOT found?
    bool isNoA = true;
    bool isNoB = true;
    
    // Additive volumes variables
    uint addVolumesCount = 0;
    float3 L0_;
    
    // Iterating through all light volumes with simplified algorithm requiring Light Volumes to be sorted by weight in descending order
    [loop]
    for (uint id = 0; id < (uint) _UdonLightVolumeCount; id++) {
        localUVW = LV_LocalFromVolume(id, worldPos);
        if (LV_PointLocalAABB(localUVW)) { // Intersection test
            if (id < (uint) _UdonLightVolumeAdditiveCount) { // Sampling additive volumes
                if (addVolumesCount < (uint) _UdonLightVolumeAdditiveMaxOverdraw) {
                    LV_SampleVolumeL0(id, localUVW, L0_);
                    L0 += L0_;
                    addVolumesCount++;
                } 
            } else if (isNoA) { // First, searching for volume A
                volumeID_A = id;
                localUVW_A = localUVW;
                isNoA = false;
            } else { // Next, searching for volume B if A found
                volumeID_B = id;
                localUVW_B = localUVW;
                isNoB = false;
                break;
            }
        }
    }
    
    // Volume A SH components and mask to blend volume sides
    float3 L0_A  = float3(1, 1, 1);

    // If no volumes found, using Light Probes as fallback
    if (isNoA && _UdonLightVolumeProbesBlend) {
        L0_ = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
        L0  += L0_;
        return;
    }
        
    // Fallback to lowest weight light volume if oudside of every volume
    localUVW_A = isNoA ? localUVW : localUVW_A;
    volumeID_A = isNoA ? _UdonLightVolumeCount - 1 : volumeID_A;

    // Sampling Light Volume A
    LV_SampleVolumeL0(volumeID_A, localUVW_A, L0_A);
    
    float mask = LV_BoundsMask(localUVW_A, _UdonLightVolumeInvLocalEdgeSmooth[volumeID_A]);
    if (mask == 1 || isNoA || (_UdonLightVolumeSharpBounds && isNoB)) { // Returning SH A result if it's the center of mask or out of bounds
        L0  += L0_A;
        return;
    }
    
    // Volume B SH components
    float3 L0_B  = float3(1, 1, 1);

    if (isNoB && _UdonLightVolumeProbesBlend) { // No Volume found and light volumes blending enabled

        // Sample Light Probes B
        L0_B = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);

    } else { // Blending Volume A and Volume B
            
        // If no volume b found, use last one found to fallback
        localUVW_B = isNoB ? localUVW : localUVW_B;
        volumeID_B = isNoB ? _UdonLightVolumeCount - 1 : volumeID_B;
            
        // Sampling Light Volume B
        LV_SampleVolumeL0(volumeID_B, localUVW_B, L0_B);
        
    }
        
    // Lerping SH components
    L0  += lerp(L0_B,  L0_A,  mask);

}

#endif