#include "HostDeviceSharedMacros.h"
#include "HostDeviceData.h"
import Raytracing;
import ShaderCommon;
import Shading;     
import Lights;
import BRDF;
#include "Constants.hlsli"
#include "Geometry.hlsli"
#include "Spectrum.hlsli"
#include "AlphaTesting.hlsli"
#include "Sampling.hlsli"
#include "BxDF.hlsli"
#include "Integrators/Path.hlsli"

RWTexture2D<float4> gRayOriginOnLens;
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
    
    // Reconstruct the primary used to populate the G-Buffer.
	RayDesc primaryRay;
	primaryRay.Origin = gRayOriginOnLens[pixelIndex].xyz;
	primaryRay.Direction = normalize(gWsPos[pixelIndex].xyz - primaryRay.Origin);
	primaryRay.TMin = 0.0f;
	primaryRay.TMax = 1e+38f;

    PathIntegrator integrator;
    integrator.maxDepth = gMaxBounces;
    L = integrator.Li(primaryRay, si, randSeed, pixelIndex);

    gOutput[pixelIndex] = float4(L, 1.0f);
}