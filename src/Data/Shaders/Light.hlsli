bool IsDeltaLight(LightData light) {
    return light.type == LightPoint || light.type == LightDirectional;
}

void Sample_Li(
    LightData light,
    Interaction it,
    inout float3 diffuseLi,
    inout float3 specularLi,
    inout float3 wi,
    inout float pdf,
    inout VisibilityTester visibility,
    ShadingData shadingData
) {
    pdf = 0.f;

    if (light.type == LightPoint) {
        // evalPointLight doesn't compute the common fields of LightSample.
        LightSample lightSample = evalLight(light, shadingData);

        wi = normalize(lightSample.L);

        // A PointLight has a delta distribution of direction; it illuminates a given
        // point of incidence from a single direction with probability 1.
        pdf = 1.f;

        // Which is intensity * falloff.
        diffuseLi = lightSample.diffuse;
        specularLi = lightSample.specular;

        visibility.n = it.n;
        visibility.p0 = it.p;
        visibility.p1 = lightSample.posW;
    } else if (light.type == LightDirectional) {
        // evalDirectionalLight doesn't compute the common fields of LightSample.
        LightSample lightSample = evalLight(light, shadingData);

        wi = normalize(lightSample.L);

        pdf = 1.f;

        diffuseLi = lightSample.diffuse;
        specularLi = lightSample.specular;

        // Place p1 outside the scene along the light source's direction. A distant
        // light doesn't emit radiance from any particular location, just along the
        // same direction.
        visibility.n = it.n;
        visibility.p0 = it.p;
        visibility.p1 = it.p + lightSample.L * (2 * 1e3f);
    }
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