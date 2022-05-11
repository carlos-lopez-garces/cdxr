// From the framework.
#include "HostDeviceSharedMacros.h"
__import Raytracing;
__import ShaderCommon;
__import Shading; 


// This shader doesn't use ray payloads.
struct SimplePayload {
	bool dummyValue;
};

[shader("raygeneration")]
void GBufferRayGen() {
    // The DispatchRaysIndex() intrinsic gives the index of this thread's ray.
    // The DispatchRaysDimensions() intrinsic gives the number of rays launched
    // and corresponds to RayLaunch::execute()'s 2nd parameter.
    float2 pixelCenter = (DispatchRaysIndex().xy + float2(0.5f, 0.5f)) / DispatchRaysDimensions().xy;

    float2 ndc = float2(2, -2) * pixelCenter + float2(-1, 1);

    // gCamera is supplied by the framework.
    float3 rayDir = ndc.x * gCamera.cameraU + ndc.y * gCamera.cameraV + gCamera.cameraW;

    RayDesc ray;
    ray.Origin = gCamera.posW;
    // A world space vector.
    ray.Direction = normalize(rayDir);
    ray.Tmin = 0.0f;
    // Intersections beyond this t are ignored.
    ray.TMax = 1e+38f;

    // Dummy payload. We specify one just because the API requires it.
    SimplePayload payload = {
        false
    };

    // gRtScene is supplied by the framework and represents the ray acceleration structure.
    // The 4th parameter is the hit group, #0. A hit group is an intersection, a closest-hit shader,
    // and an any-hit shader. Hit group #0 corresponds to primary rays.
    // hitProgramCount is supplied by the framework and is the number of hit groups that exist.
    TraceRay(gRtScene, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, 0XFF, 0, hitProgramCount, 0, ray, payload);
}

// The GBuffer.
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gMatDif;
RWTexture2D<float4> gMatSpec;
RWTexture2D<float4> gMatExtra;
RWTexture2D<float4> gMatEmissive;

cbuffer MissShaderCB {
    // Rays that escape the scene sample this (background) color in the miss shader.
	float3 gBgColor;
};

[shader("miss")]
void PrimaryMiss(inout SimplePayload) {
    gMatSpec[DispatchRaysIndex().xy] = float4(gBgColor, 1.0f);
}

#include "AlphaTest.hlsli"

// attributes are the attributes of the hit/intersection.
[shader("anyhit")]
void PrimaryAnyHit(inout SimplePayload, BuiltInTriangleIntersectionAttributes atttributes) {
    if (alphaTestFails(attributes)) {
        // The intersected geometry is transparent. Acceleration structure traversal
        // resumes after IgnoreHit().
        IgnoreHit();
    }
}

// attributes are the attributes of the hit/intersection.
[shader("closesthit")]
void PrimaryClosestHit(inout SimplePayload, BuiltInTriangleIntersectionAttributes attributes) {
    // Pixel coordinate.
    uint2 launchIndex = DispatchRaysIndex().xy;
    
    // PrimitiveIndex() is an object introspection intrinsic that returns
    // the identifier of the current primitive.
    ShadingData shadeData = getShadingData(PrimitiveIndex(), attributes);

    // Populate the GBuffer.
    gWsPos[launchIndex] = float4(shadeData.posW, 1.f);
	gWsNorm[launchIndex] = float4(shadeData.N, length(shadeData.posW - gCamera.posW));
	gMatDif[launchIndex] = float4(shadeData.diffuse, shadeData.opacity);
	gMatSpec[launchIndex] = float4(shadeData.specular, shadeData.linearRoughness);
	gMatExtra[launchIndex] = float4(shadeData.IoR, shadeData.doubleSidedMaterial ? 1.f : 0.f, 0.f, 0.f);
	gMatEmissive[launchIndex] = float4(shadeData.emissive, 0.f);
}