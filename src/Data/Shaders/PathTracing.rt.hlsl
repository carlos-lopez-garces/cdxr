#include "HostDeviceSharedMacros.h"
#include "HostDeviceData.h"
import Raytracing;
import ShaderCommon;
import Shading;     
import Lights;
import BRDF;
#include "Constants.hlsli"
#include "Spectrum.hlsli"
#include "Geometry.hlsli"
#include "Reflection.hlsli"
#include "AlphaTesting.hlsli"
#include "PRNG.hlsli"
#include "Sampling.hlsli"
#include "BxDF.hlsli"
#include "Light.hlsli"
#include "Integrator.hlsli"
#include "Integrators/Path.hlsli"

RWTexture2D<float4> gRayOriginOnLens;
RWTexture2D<float4> gPrimaryRayDirection;
Texture2D<float4> gWsPos;
// Shading normal.
Texture2D<float4> gWsNorm;
Texture2D<float4> gWsShadingNorm;
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
    
    // Reconstruct the primary ray used to populate the G-Buffer.
	RayDesc primaryRay;
	primaryRay.Origin = gRayOriginOnLens[pixelIndex].xyz;
    // gOutput[pixelIndex] = gRayOriginOnLens[pixelIndex];

    // The direction of the primary ray used to be reconstructed as follows:
    //  normalize(gWsPos[pixelIndex].xyz - primaryRay.Origin)
    // but this is unreliable because there's no valid hit point in gWsPos when
    // the primary ray misses.
	primaryRay.Direction = gPrimaryRayDirection[pixelIndex].xyz;
    // DEBUG:
    // primaryRay.Direction = -primaryRay.Direction;
	primaryRay.TMin = 0.0f;
	primaryRay.TMax = 1e+38f;

    PathIntegrator integrator;
    integrator.maxDepth = gMaxBounces;
    // DEBUG: pixels become ever brighter. What happens if maxDepth is smaller?
    // =0: All black, except vases, which are pink. Because when there's intersection in bounce 0, routine bails out
    //     before updating L.
    // =1: No more brightening. No color, though, just grayscale. No AO either nor shadows.
    // =2: There's color, but becomes very bright and white very quickly.
    // integrator.maxDepth = 2;
    L = integrator.Li(primaryRay, randSeed, pixelIndex);
    // DEBUG: what color is sampled by rays pointing to the environment map? Map is rendered correctly.
    // L = gMatDif[pixelIndex].xyz;

    gOutput[pixelIndex] = float4(L, 1.0f);
}