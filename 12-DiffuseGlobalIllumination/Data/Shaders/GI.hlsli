struct GIRayPayload {
    float4 sampledInterreflectionColor;
    float4 samplePoint;
    float3 samplePointNormal;
};

float4 shootGIRay(float3 surfacePoint, float3 surfaceNormal, uint randSeed) {
    // Indirect illumination.
    float3 bounceDirection = getCosHemisphereSample(randSeed, surfaceNormal);
    RayDesc ray;
    ray.Origin = surfacePoint;
    ray.Direction = bounceDirection;
    ray.TMin = gTMin;
    ray.TMax = gTMax;

    GIRayPayload payload;        
    // Initial interreflection color.
    payload.sampledInterreflectionColor = float4(1.0f, 1.0f, 1.0f, 1.0f);
    float BdotN = saturate(dot(bounceDirection, surfaceNormal));
    float bouncePdf = BdotN / M_PI;

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

    return payload.sampledInterreflectionColor;
}

[shader("closesthit")]
void GIClosestHit(inout GIRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
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
void GIAnyHit(inout GIRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    if(alphaTestFails(attributes)) {
        IgnoreHit();
    }
}

[shader("miss")]
void GIMiss(inout GIRayPayload payload) {

}