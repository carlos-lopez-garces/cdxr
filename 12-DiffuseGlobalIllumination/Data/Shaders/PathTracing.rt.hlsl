#include "HostDeviceSharedMacros.h"
#include "HostDeviceData.h"
import Raytracing;
import ShaderCommon;
import Shading;     
import Lights;
#include "Constants.hlsli"
#include "AlphaTesting.hlsli"
#include "GI.hlsli"
#include "Sampling.hlsli"
#include "Shadows.hlsli"
#include "Lighting.hlsli"
#include "BxDF.hlsli"
#include "Integrators/Path.hlsli"

Texture2D<float4> gWsPos;
// Shading normal.
Texture2D<float4> gWsNorm;
Texture2D<float4> gWsShadingNorm;
Texture2D<float4> gMatDif;
Texture2D<float4> gMatEmissive;
RWTexture2D<float4> gOutput;

cbuffer RayGenCB {
    uint gFrameCount;
    uint gMaxBounces;
    uint gMinBouncesBeforeRussianRoulette;
    float gTMin;
    float gTMax;
    bool gDoCosineSampling;
}

[shader("raygeneration")]
void PathTracingRayGen() {
    uint2 pixelIndex = DispatchRaysIndex().xy;
    uint2 pixelCount = DispatchRaysDimensions().xy;

    uint frameCount = gFrameCount;
    uint randSeed = initRand(pixelIndex.x + pixelIndex.y * pixelCount.x, frameCount, 16);

    // Radiance.
    float3 L = float3(0.0f, 0.0f, 0.0f);
    float3 throughput = float3(1.0f, 1.0f, 1.0f);

    SurfaceInteraction si;
    // Ray origin at primary hit point.
    si.p = gWsPos[pixelIndex].xyz;
    // Geometric normal.
    si.n = gWsNorm[pixelIndex].xyz; 
    si.shadingNormal = gWsShadingNorm[pixelIndex].xyz; 
    // Read surface diffuse color or environment color from G-Buffer.
    si.color = gMatDif[pixelIndex];
    si.emissive = gMatEmissive[pixelIndex].rgb;
    
    PathIntegrator integrator;
    integrator.maxDepth = gMaxBounces;
    L = integrator.Li(si, randSeed);

    gOutput[pixelIndex] = float4(L, 1.0f);
}