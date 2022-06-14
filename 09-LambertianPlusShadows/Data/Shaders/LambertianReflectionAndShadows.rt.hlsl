// From Falcor.
#include "HostDeviceSharedMacros.h"
#include "HostDeviceData.h"           
import Raytracing;
import ShaderCommon;
import Shading;     
import Lights;
#include "AlphaTesting.hlsli"
// Already includes PRNG.hlsli.
#include "Sampling.hlsli"
#include "Lighting.hlsli"

// G-Buffer.
RWTexture2D<float4> gPos;
RWTexture2D<float4> gNorm;
RWTexture2D<float4> gMatDif;
RWTexture2D<float4> gOutput;

// Payload for shadow rays.
struct ShadowRayPayload {
    // 0.0 if completely occluded, 1.0 if directly and completely light. 
	float visibilityFactor;
};

cbuffer RayGenCB {
	float gMinT;
    uint gFrameCount;
    bool gSampleOnlyOneLight;
    bool gShadows;
};

float shootShadowRay(float3 origin, float3 direction, float minT, float maxT) {
    RayDesc shadowRay;
    shadowRay.Origin = origin;
    shadowRay.Direction = direction;
    shadowRay.TMin = minT;
    shadowRay.TMax = maxT;

    ShadowRayPayload payload = { 0.0f };

    TraceRay(
        // Ray acceleration structure supplied by Falcor.
        gRtScene,
        // We don't use the closesthit shader.
        RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH | RAY_FLAG_SKIP_CLOSEST_HIT_SHADER,
        0xFF,
        // Hit group #0.
        0,
        // hitProgramCount is supplied by the framework and is the number of hit groups that exist.
        hitProgramCount,
        0,
        shadowRay,
        payload
    );

    return payload.visibilityFactor;
}

float3 sampleLight(int lightIndex, float4 worldPosition, float4 worldNormal, float pdf) {
    float distanceToLight;
    float3 lightIntensity;
    float3 directionToLight;
    getLightData(lightIndex, worldPosition.xyz, directionToLight, lightIntensity, distanceToLight);

    // Compute lambertian factor.
    float LdotN = saturate(dot(directionToLight, worldNormal.xyz));

    // Dividing by the probability of choosing this light is crucial!
    float shadowFactor = 1.0f / pdf;
    if (gShadows) {
        shadowFactor = shootShadowRay(worldPosition.xyz, directionToLight, gMinT, distanceToLight) / pdf;
    }

    return lightIntensity * LdotN * shadowFactor;
}

[shader("raygeneration")]
void LambertAndShadowsRayGen() {
    // The DispatchRaysIndex() intrinsic gives the index of this thread's ray. We use it to
	// identify the pixel.
	uint2 pixelIndex = DispatchRaysIndex().xy;

	// The DispatchRaysDimensions() intrinsic gives the number of rays launched and corresponds
	// to RayLaunch::execute()'s 2nd parameter: the total number of pixels.
	uint2 pixelCount = DispatchRaysDimensions().xy;

    // Textures support 2D indexing.
    float4 worldPosition = gPos[pixelIndex];
    float4 worldNormal = gNorm[pixelIndex];
    float4 diffuseMatColor = gMatDif[pixelIndex];

    // Background color for when the ray escapes the scene without hitting anything.
    float3 pixelColor = diffuseMatColor.rgb;

    if (worldPosition.w != 0.0f) {
        pixelColor = float3(0.0f, 0.0f, 0.0f);

        if (gSampleOnlyOneLight) {
            uint randSeed = initRand(pixelIndex.x + pixelIndex.y * pixelCount.x, gFrameCount, 16);
            int lightIndex = min(int(nextRand(randSeed)*gLightsCount), gLightsCount - 1);
            // Uniform distribution.
            float pdf = 1.0f / gLightsCount;
            pixelColor += sampleLight(lightIndex, worldPosition, worldNormal, pdf);
        } else {
            // Light sources are exposed by Falcor.
            for (int lightIndex = 0; lightIndex < gLightsCount; lightIndex++) {
                float pdf = 1.0f;
                pixelColor += sampleLight(lightIndex, worldPosition, worldNormal, pdf);
            }
        }

        float PI = 3.14159265f;
        pixelColor *= diffuseMatColor.rgb / PI; 
    }

    gOutput[pixelIndex] = float4(pixelColor, 1.0f);
}

[shader("miss")]
void ShadowMiss(inout ShadowRayPayload payload) {
    // The shadow ray didn't hit anything, which means that the point being shaded is unoccluded.
    payload.visibilityFactor = 1.0f;
}

// BuiltInTriangleIntersectionAttributes just contains float2 barycentrics. See 
// https://docs.microsoft.com/en-us/windows/win32/direct3d12/intersection-attributes.
[shader("anyhit")]
void ShadowAnyHit(inout ShadowRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    // Is this a transparent part of the surface?  If so, ignore this hit
	if (alphaTestFails(attributes)) {
        IgnoreHit();
    }
}

[shader("closesthit")]
void ShadowClosestHit(inout ShadowRayPayload payload, BuiltInTriangleIntersectionAttributes attribs) {
    // By ShadowRayPayload.visibilityFactor = 0.0 be the default value, it is assumed that the
    // shadow ray will hit an occluder; if there's none, the miss shader will set it 1.0.
    //
    // This is technically not necessary.
    payload.visibilityFactor = 0.0;
}