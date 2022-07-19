#include "Geometry.hlsli"

struct GIRayPayload {
    float4 sampledInterreflectionColor;
    uint randSeed;
    bool doShadows;
};

// Environment map;
Texture2D<float4> gEnvMap;

float4 shootGIRay(inout SurfaceInteraction si, uint randSeed, bool doShadows, bool doCosineSampling) {
    // Indirect illumination.
    float3 bounceDirection;
    if (doCosineSampling) {
        bounceDirection = getCosHemisphereSample(randSeed, si.n);
    } else {
        bounceDirection = getUniformHemisphereSample(randSeed, si.n);
    }

    RayDesc ray;
    ray.Origin = si.p;
    ray.Direction = bounceDirection;
    ray.TMin = gTMin;
    ray.TMax = gTMax;

    // Lambertian factor.
    float BdotN = saturate(dot(bounceDirection, si.n));

    float bouncePdf;
    if (doCosineSampling) {
        bouncePdf = BdotN / M_PI;
    } else {
        bouncePdf = 1.0f / (2.0f * M_PI);
    }

    GIRayPayload payload;
    payload.sampledInterreflectionColor = float4(0.0f, 0.0f, 0.0f, 0.0f);
    payload.randSeed = randSeed;
    payload.doShadows = doShadows;

    TraceRay(
        gRtScene,
        RAY_FLAG_NONE,
        0xFF,
        // Hit group #0.
        STANDARD_RAY_HIT_GROUP,
        // hitProgramCount is supplied by the framework and is the number of hit groups that exist.
        hitProgramCount,
        // Miss shader?
        STANDARD_RAY_HIT_GROUP,
        ray,
        payload,
    );

    return (payload.sampledInterreflectionColor * si.color * BdotN / M_PI) / bouncePdf;
}

[shader("closesthit")]
void GIClosestHit(inout GIRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    // PrimitiveIndex() is an object introspection intrinsic that returns
    // the identifier of the current primitive.
    ShadingData shadeData = getShadingData(PrimitiveIndex(), attributes);

    int lightToSample = min(int(nextRand(payload.randSeed) * gLightsCount), gLightsCount - 1);
    payload.sampledInterreflectionColor = float4(shadeData.diffuse.rgb * sampleLight(lightToSample, shadeData.posW, shadeData.N, payload.doShadows, gTMin), 1.0f);
}

[shader("anyhit")]
void GIAnyHit(inout GIRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    if(alphaTestFails(attributes)) {
        IgnoreHit();
    }
}

[shader("miss")]
void GIMiss(inout GIRayPayload payload) {
	float2 envMapDimensions;
	gEnvMap.GetDimensions(envMapDimensions.x, envMapDimensions.y);

	float2 uv = WorldToLatitudeLongitude(WorldRayDirection());

    payload.sampledInterreflectionColor = float4(gEnvMap[uint2(uv * envMapDimensions)].rgb, 1.0f);
}