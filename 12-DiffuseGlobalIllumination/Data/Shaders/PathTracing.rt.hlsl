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
    
    for (int bounce = 0; bounce < gMaxBounces; ++bounce) {
        L += throughput * si.emissive;

        // Direct illumination.
        // gLightsCount and getLightData() are automatically imported by Falcor.
        int lightToSample = min(int(nextRand(randSeed) * gLightsCount), gLightsCount - 1);
        L += throughput * si.color.rgb * sampleLight(lightToSample, si.p, si.shadingNormal, true, gTMin);

        shootGIRay(si, randSeed, true);
        if (!si.hasHit()) {
            // TODO: account for environment map.
            L += throughput;
            break;
        }

        if (bounce == gMaxBounces - 1) {
            // No need to sample BDRF on last bounce.
            break;
        }

        // Terminate path probabilistically via Russian Roulette.
        if (bounce > gMinBouncesBeforeRussianRoulette) {
            // (Relative) luminance Y is 0-1 luminance normalized to [0.0, 1.0]. The relative luminance of an RGB
            // color is a grayscale color and is obtained via dot product with a constant vector that has a
            // higher green component because that's the color that the retina perceives the most.
            // Defined in HostDeviceSharedCode.h
            float rrPdf = min(0.95f, luminance(throughput));
            if (rrPdf < nextRand(randSeed)) {
                // At least 0.05 probability of terminating.
                //
                // Warning: terminating paths increases the variance of the estimator.
                break;
            } else {
                // Increase throughput, thereby decreasing the probability of terminating?
                throughput /= rrPdf;
            }
        }

        int brdfType;
        // if (si.metalness == 1.0f && si.roughness == 0.0f) {
        //     brdfType = BXDF_SPECULAR;
        // } else {

        // }

        si.p = offsetRayOrigin(si.p, si.n);
    }

    gOutput[pixelIndex] = float4(L, 1.0f);
}