struct GIRayPayload {
    float4 sampledInterreflectionColor;
    uint randSeed;
    bool doShadows;
};

// Environment map;
Texture2D<float4> gEnvMap;

float4 shootGIRay(float3 surfacePoint, float3 surfaceNormal, float4 surfaceColor, uint randSeed, bool doShadows, bool doCosineSampling) {
    // Indirect illumination.
    float3 bounceDirection;
    if (doCosineSampling) {
        bounceDirection = getCosHemisphereSample(randSeed, surfaceNormal);
    } else {
        bounceDirection = getUniformHemisphereSample(randSeed, surfaceNormal);
    }

    RayDesc ray;
    ray.Origin = surfacePoint;
    ray.Direction = bounceDirection;
    ray.TMin = gTMin;
    ray.TMax = gTMax;

    // Lambertian factor.
    float BdotN = saturate(dot(bounceDirection, surfaceNormal));

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
        1,
        // hitProgramCount is supplied by the framework and is the number of hit groups that exist.
        hitProgramCount,
        // Miss shader?
        1,
        ray,
        payload,
    );

    return (payload.sampledInterreflectionColor * surfaceColor * BdotN / M_PI) / bouncePdf;
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