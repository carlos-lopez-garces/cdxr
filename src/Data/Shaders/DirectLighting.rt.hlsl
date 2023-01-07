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
#include "FresnelEquations.hlsli"
#include "Distributions/GGXNormalDistribution.hlsli"
#include "BxDFs/BxDF.hlsli"
#include "Light.hlsli"
#include "Integrator.hlsli"
#include "Integrators/Direct.hlsli"

RWTexture2D<float4> gRayOriginOnLens;
RWTexture2D<float4> gPrimaryRayDirection;
RWTexture2D<float4> gOutput;

cbuffer RayGenCB {
    uint gFrameCount;
    uint gMaxBounces;
    float gTMin;
    float gTMax;
}

[shader("raygeneration")]
void DirectLightingRayGen() {
    uint2 pixelIndex = DispatchRaysIndex().xy;
    uint2 pixelCount = DispatchRaysDimensions().xy;

    uint frameCount = gFrameCount;
    uint randSeed = initRand(pixelIndex.x + pixelIndex.y * pixelCount.x, frameCount, 16);

    // Reconstruct the primary ray used to populate the G-Buffer.
	RayDesc primaryRay;
	primaryRay.Origin = gRayOriginOnLens[pixelIndex].xyz;

    // The direction of the primary ray used to be reconstructed as follows:
    //  normalize(gWsPos[pixelIndex].xyz - primaryRay.Origin)
    // but this is unreliable because there's no valid hit point in gWsPos when
    // the primary ray misses.
	primaryRay.Direction = gPrimaryRayDirection[pixelIndex].xyz;
	primaryRay.TMin = 0.0f;
	primaryRay.TMax = 1e+38f;

    DirectLightingIntegrator integrator;
	integrator.maxDepth = gMaxBounces;
    float3 L = integrator.Li(primaryRay, randSeed, pixelIndex, 0);
    
    gOutput[pixelIndex] = float4(L, 1.0f);
}