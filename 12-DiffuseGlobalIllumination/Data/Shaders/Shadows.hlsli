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

// Payload for shadow rays.
struct ShadowRayPayload {
    // 0.0 if completely occluded, 1.0 if directly and completely light. 
	float visibilityFactor;
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