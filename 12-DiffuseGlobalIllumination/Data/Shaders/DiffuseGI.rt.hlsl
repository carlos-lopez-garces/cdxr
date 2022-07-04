#include "HostDeviceSharedMacros.h"
#include "HostDeviceData.h"           
import Raytracing;
import ShaderCommon;
import Shading;     
import Lights;
#include "Shadows.hlsli"
#include "Lighting.hlsli"

// G-Buffer.
Texture2D<float4> gWsPos;
Texture2D<float4> gWsNorm;
Texture2D<float4> gMatDif;

RWTexture2D<float4> gOutput;

struct RayPayload {
    float4 sampledInterreflectionColor;
    float4 samplePoint;
    float3 samplePointNormal;
};

cbuffer RayGenCB {
    uint gFrameCount;
    float gTMin;
    float gTMax;
    uint gRecursionDepth;
    bool gDoDirectShadows;
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
        // Sample uniformly.
        float pdf = 1.0f / gLightsCount;
        gOutput[pixelIndex] = float4(pixelColor.xyz * sampleLight(lightToSample, gWsPos[pixelIndex], gWsNorm[pixelIndex], pdf, gDoDirectShadows, gTMin), 1.0f);

        // Indirect illumination.
        RayDesc ray;
        ray.Origin = gWsPos[pixelIndex].xyz;
        ray.Direction = getCosHemisphereSample(randSeed, gWsNorm[pixelIndex].xyz).xyz;
        ray.TMin = gTMin;
        ray.TMax = gTMax;

        RayPayload payload;        
        // Initial interreflection color.
        payload.sampledInterreflectionColor = float4(1.0f, 1.0f, 1.0f, 1.0f);

        for (uint i=0; i<gRecursionDepth; ++i) {
            TraceRay(
                gRtScene,
                RAY_FLAG_NONE,
                0xFF,
                // Hit group #0.
                1,
                // hitProgramCount is supplied by the framework and is the number of hit groups that exist.
                hitProgramCount,
                // Miss shader?
                1,
                ray,
                payload,
            );

            gOutput[pixelIndex] *= payload.sampledInterreflectionColor;

            // Next sample point.
            ray.Origin = payload.samplePoint.xyz;
            ray.Direction = getCosHemisphereSample(randSeed, payload.samplePointNormal).xyz;
        }
    }
}

[shader("closesthit")]
void GIClosestHit(inout RayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    // PrimitiveIndex() is an object introspection intrinsic that returns
    // the identifier of the current primitive.
    ShadingData shadeData = getShadingData(PrimitiveIndex(), attributes);

	// gWsNorm[launchIndex] = float4(shadeData.N, length(shadeData.posW - gCamera.posW));
	// gMatDif[launchIndex] = float4(shadeData.diffuse, shadeData.opacity);
	// gMatSpec[launchIndex] = float4(shadeData.specular, shadeData.linearRoughness);
	// gMatExtra[launchIndex] = float4(shadeData.IoR, shadeData.doubleSidedMaterial ? 1.f : 0.f, 0.f, 0.f);
	// gMatEmissive[launchIndex] = float4(shadeData.emissive, 0.f);

    payload.sampledInterreflectionColor = float4(shadeData.diffuse, shadeData.opacity);
    payload.samplePoint = float4(shadeData.posW, 1.f);
    payload.samplePointNormal = shadeData.N;
}

[shader("anyhit")]
void GIAnyHit(inout RayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    if(alphaTestFails(attributes)) {
        IgnoreHit();
    }
}

[shader("miss")]
void GIMiss(inout RayPayload payload) {

}