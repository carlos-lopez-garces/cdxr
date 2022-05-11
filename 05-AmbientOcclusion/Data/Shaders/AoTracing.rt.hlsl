#include "HostDeviceSharedMacros.h" 
__import Raytracing;
__import ShaderCommon;
__import Shading;

#include "PRNG.hlsli"
#include "Sampling.hlsli"

cbuffer RayGenCB {
    // Determines a pixel's nearby geometry that participates in the pixel's AO.
    float gAoRadius;

    // Used as initialization seed for the PRNG.
    uint gFrameCount;

    // Minimum value of the ray's t parameter; t >= gMinT ensures that the ray
    // doesn't intersect again the nearby region of the geometry where its origin is.
    float gMinT;

    // Number of rays per pixel.
    uint gNumRays;
};

// Rasterized G-Buffer from SimpleGBufferPass.
Texture2D<float4> gPos;
Texture2D<float4> gNorm;

RWTexture2D<float4> gOutput;

struct AoRayPayload{
	float aoValue;
};

float spawnAoRay(float3 origing, float3 direction, float minT, float maxT) {
    // Carries AO value.
    AoRayPayload payload = { 0.0f };
    RayDesc aoRay;
    aoRay.Origin = orig;
    aoRay.Direction = direction;
    aoRay.TMin = minT;
    aoRay.TMax = maxT;

    TraceRay(
        // Ray acceleration structure supplied by Falcor.
        gRtScene
        // We don't use the closesthit shader.
        RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH | RAY_FLAG_SKIP_CLOSEST_HIT_SHADER,
        0xFF,
        // Hit group #0.
        0,
        // hitProgramCount is supplied by the framework and is the number of hit groups that exist.
        hitProgramCount,
        0,
        aoRay,
        payload
    );

    return payload.aoValue;
}

[shader("raygeneration")]
void AoRayGen () {
    uint2 launchIndex = DispatchRaysIndex().xy;
    uint2 launchDim = DispatchRaysDimensions().xy;

    uint prngSeed = initRand(launchIndex.x + launchIndex.y * launchDim.x, gFrameCount, 16);

    // Textures support 2D indexing.
    float4 worldPosition = gPos[launchIndex];
    float4 worldNormal = gNorm[launchIndex];

    // The ambient occlusion value starts out with a value of gNumRays. If the ray
    // escapes the scene, gNumRays/gNumRays = 1.0 will be the AO color of the pixel. 
    // (gNumRays is the number of rays per pixel.)
    float ao = float(gNumRays);

    // The WorldPosition G-Buffer is created by SimpleGBufferPass using rasterization.
    // Draw calls execute for triangles. If a pixel cover a fragment of a triangle, the
    // pixel shader sets the w coordinate equal to 1.0 in the corresponding pixel in the
    // WorldPosition G-Buffer. Since the G-Buffer textures are cleared to black at render
    // pass initialization, all pixels of the WorldPosition G-Buffer that don't cover
    // triangles remain untouched with a value of 0.0. We use this fact to know if this
    // primary ray would actually intersect geometry. 
    if (worldPosition.w != 0.0f) {
        ao = 0.0f;

        for (int i = 0; i < gNumRays; ++i) {
            // Cosine-weighted sampling of the hemisphere of directions.
            float3 worldDirection = getCosHemisphereSample(seed, worldNormal.xyz);

            // 1.0 if the ray doesn't hit any geometry.
            ao += spawnAoRay(worldPosition.xyz, worldDirection, gMinT, gAoRadius);
        }
    }

    float aoColor = ao / float(gNumRays);
    gOutput[launchIndex] = float4(aoColor, aoColor, aoColor, 1.0f);
}

[shader("miss")]
void AoMiss(inout AoRayPayload payload) {
	payload.aoValue = 1.0f;
}

[shader("anyhit")]
void AoAnyHit(inout AoRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
	if (alphaTestFails(attributes)) {
        // The intersected geometry is transparent. Acceleration structure traversal
        // resumes after IgnoreHit().
        IgnoreHit();   
    }
}