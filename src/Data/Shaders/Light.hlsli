bool IsDeltaLight(LightData light) {
    return light.type == LightPoint || light.type == LightDirectional;
}

struct ShadowRayPayload {
    bool hit;
};

void spawnShadowRay(RayDesc ray, inout SurfaceInteraction si) {
    ShadowRayPayload payload;
    payload.hit = false;

    TraceRay(
        gRtScene,
        RAY_FLAG_NONE,
        0xFF,
        SHADOW_RAY_HIT_GROUP,
        hitProgramCount,
        SHADOW_RAY_HIT_GROUP,
        ray,
        payload,
    );

    si.hit = payload.hit;
}

[shader("closesthit")]
void ShadowClosestHit(inout ShadowRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    payload.hit = true;
}

[shader("anyhit")]
void ShadowAnyHit(inout ShadowRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    if (alphaTestFails(attributes)) {
        IgnoreHit();
    }
}

[shader("miss")]
void ShadowMiss(inout ShadowRayPayload payload) {
    payload.hit = false;
}

struct VisibilityTester {
    // Geometric normal of surface at p0. Used to avoid self-intersection.
    float3 n;
    float3 p0;
    float3 p1;

    bool Unoccluded() {
        if (n.x == 0.f && n.y == 0.f && n.z == 0.f) {
            return true;
        }

        RayDesc shadowRay;
        shadowRay.Origin = offsetRayOrigin(p0, n);
        shadowRay.Direction = normalize(p1 - p0);
        shadowRay.TMin = 0.0f;
        shadowRay.TMax = distance(shadowRay.Origin, p1);
        
        SurfaceInteraction si;
        spawnShadowRay(shadowRay, si);

        return !si.hit;
    }
};