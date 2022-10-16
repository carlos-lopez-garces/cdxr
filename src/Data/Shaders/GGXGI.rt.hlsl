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
#include "Sampling.hlsli"
#include "Shadows.hlsli"
#include "Lighting.hlsli"
#include "Microfacet.hlsli"
#include "Integrators/Direct.hlsli"

shared cbuffer GlobalCB {
    float gMinT;
    uint gFrameCount;
    bool gDoIndirectGI;
    bool gDoDirectGI;
    uint gMaxDepth;
    float gEmitMult;
}

shared Texture2D<float4> gPos;
shared Texture2D<float4> gNorm;
shared Texture2D<float4> gDiffuseMatl;
shared Texture2D<float4> gSpecMatl;
shared Texture2D<float4> gExtraMatl;
shared Texture2D<float4> gEnvMap;
shared Texture2D<float4> gEmissive;
shared RWTexture2D<float4> gOutput;

[shader("raygeneration")]
void GGXGIRayGen() {
    uint2 pixelIndex = DispatchRaysIndex().xy;
	uint2 pixelCount = DispatchRaysDimensions().xy;
    uint randSeed = initRand(pixelIndex.x + pixelIndex.y * pixelCount.x, gFrameCount, 16);

    // G-Buffer.
    float4 worldPos = gPos[pixelIndex];
	float4 worldNorm = gNorm[pixelIndex];
	float4 difMatlColor = gDiffuseMatl[pixelIndex];
	float4 specMatlColor = gSpecMatl[pixelIndex];
	float4 extraData = gExtraMatl[pixelIndex];

    bool pixelContainsGeometry = (worldPos.w != 0.0f);

    float roughness = specMatlColor.a * specMatlColor.a;

    // Eye vector.
    float3 V = normalize(gCamera.posW - worldPos.xyz);
    if (dot(worldNorm.xyz, V) <= 0.0f) {
        worldNorm.xyz = -worldNorm.xyz;
    }
	float NdotV = dot(worldNorm.xyz, V);

    float3 noMapN = normalize(extraData.yzw);
	if (dot(noMapN, V) <= 0.0f) {
        noMapN = -noMapN;
    }

    // If not, assign background color to pixel.
    float3 pixelColor = pixelContainsGeometry ? float3(0, 0, 0) : difMatlColor.rgb;
    if (pixelContainsGeometry) {
        pixelColor = gEmitMult * gEmissive[pixelIndex].rgb;

        if (gDoDirectGI) {
            DirectLightingIntegrator integrator;
            RayDesc ray;
            pixelColor += integrator.Li(
                ray,
                randSeed,
                pixelIndex,
                worldPos.xyz,
                worldNorm.xyz,
                V,
				difMatlColor.rgb,
                specMatlColor.rgb,
                roughness
            );
        }

        if (gDoIndirectGI && gMaxDepth > 0) {
            pixelColor += ggxIndirect(
                randSeed,
                worldPos.xyz,
                worldNorm.xyz,
                noMapN,
				V,
                difMatlColor.rgb,
                specMatlColor.rgb,
                roughness, 
                0
            );
        }
    }    

    // NaN's and other invalid values?
    bool isNaN = any(isnan(pixelColor));

    gOutput[pixelIndex] = float4(isNaN ? float3(0, 0, 0) : pixelColor, 1.0f);
}