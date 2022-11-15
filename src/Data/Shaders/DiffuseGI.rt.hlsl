#include "HostDeviceSharedMacros.h"
#include "HostDeviceData.h"           
import Raytracing;
import ShaderCommon;
import Shading;     
import Lights;
#include "Constants.hlsli"
#include "Spectrum.hlsli"
#include "PRNG.hlsli"
#include "Geometry.hlsli"
#include "AlphaTesting.hlsli"
#include "Shadows.hlsli"
#include "Lighting.hlsli"
#include "Sampling.hlsli"
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
    bool gDoDirectShadows;
    bool gDoGI;
    bool gDoCosineSampling;
};

[shader("raygeneration")]
void DiffuseGIRayGen() {
    float2 pixelIndex = DispatchRaysIndex().xy;
    float2 pixelCount = DispatchRaysDimensions().xy;

    // Read surface diffuse color or environment color from G-Buffer.
    float4 pixelDiffuseColor = gMatDif[pixelIndex];

    // If the primary closest hit shader didn't execute for this pixel because the ray didn't
    // hit any geometry, the world position vector will be the 0 vector, including its w component. 
    if (gWsPos[pixelIndex].w == 0.0) {
        // Primary ray hit the environment map.
        gOutput[pixelIndex] = pixelDiffuseColor;
    } else {
        uint frameCount = gFrameCount;
        uint randSeed = initRand(pixelIndex.x + pixelIndex.y * pixelCount.x, frameCount, 16);

        float4 shadeColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

        // Direct illumination.
        // gLightsCount and getLightData() are automatically imported by Falcor.
        int lightToSample = min(int(nextRand(randSeed) * gLightsCount), gLightsCount - 1);
        shadeColor += float4(pixelDiffuseColor.rgb * sampleLight(lightToSample, gWsPos[pixelIndex].xyz, gWsNorm[pixelIndex].xyz, gDoDirectShadows, gTMin), 1.0f);

        // Indirect illumination.
        if (gDoGI) {
            SurfaceInteraction si; si.p = gWsPos[pixelIndex].xyz; si.n = gWsNorm[pixelIndex].xyz; si.color = pixelDiffuseColor;
            float4 interreflectionColor = shootGIRay(si, randSeed, gDoCosineSampling);
            shadeColor += interreflectionColor;
        }

        gOutput[pixelIndex] = shadeColor;
    }
}