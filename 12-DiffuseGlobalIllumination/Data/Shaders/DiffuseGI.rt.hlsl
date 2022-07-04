#include "HostDeviceSharedMacros.h"
#include "HostDeviceData.h"           
import Raytracing;
import ShaderCommon;
import Shading;     
import Lights;
#include "Shadows.hlsli"
#include "Lighting.hlsli"
#include "GI.hlsli"

// G-Buffer.
Texture2D<float4> gWsPos;
Texture2D<float4> gWsNorm;
Texture2D<float4> gMatDif;

RWTexture2D<float4> gOutput;

cbuffer RayGenCB {
    uint gFrameCount;
    float gTMin;
    float gTMax;
    uint gRecursionDepth;
    bool gDoDirectShadows;
    bool gDoGI;
};

[shader("raygeneration")]
void DiffuseGIRayGen() {
    float2 pixelIndex = DispatchRaysIndex().xy;
    float2 pixelCount = DispatchRaysDimensions().xy;

    // Read environment map or background color from G-Buffer.
    float4 pixelColor = gMatDif[pixelIndex];

    // If the primary closest hit shader didn't execute for this pixel because the ray didn't
    // hit any geometry, the world position vector will be the 0 vector, including its w component. 
    if (gWsPos[pixelIndex].w == 0.0) {
        // Primary ray hit the environment map.
        gOutput[pixelIndex] = pixelColor;
    } else {
        uint frameCount = gFrameCount;
        uint randSeed = initRand(pixelIndex.x + pixelIndex.y * pixelCount.x, frameCount, 16);

        // Direct illumination.
        // gLightsCount and getLightData() are automatically imported by Falcor.
        int lightToSample = min(int(nextRand(randSeed) * gLightsCount), gLightsCount - 1);
        gOutput[pixelIndex] = float4(pixelColor.rgb * sampleLight(lightToSample, gWsPos[pixelIndex], gWsNorm[pixelIndex], gDoDirectShadows, gTMin), 1.0f);

        // Indirect illumination.
        if (gDoGI) {
            float4 interreflectionColor = shootGIRay(gWsPos[pixelIndex].xyz, gWsNorm[pixelIndex].xyz, randSeed);
            gOutput[pixelIndex] += interreflectionColor;
        }
    }
}