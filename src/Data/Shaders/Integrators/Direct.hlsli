struct DLRayPayload {
    uint randSeed;
    float3 shadingNormal;
    float3 normal;
    float3 hitPoint;
    uint2 pixelIndex;
    bool hit;
};

RWTexture2D<float3> gDirectL;
RWTexture2D<float3> gLe;

RWTexture2D<float4> gDiffuseBRDF;
RWTexture2D<float4> gDiffuseColor;
RWTexture2D<float4> gSpecularBRDF;
RWTexture2D<float3> gBRDFProbability;

Texture2D<float4> gEnvMap;

void spawnRay(RayDesc ray, inout SurfaceInteraction si, uint randSeed, uint2 pixelIndex) {
    DLRayPayload payload;
    payload.randSeed = randSeed;
    payload.pixelIndex = pixelIndex;
    payload.hit = false;

    TraceRay(
        gRtScene,
        RAY_FLAG_CULL_BACK_FACING_TRIANGLES,
        0xFF,
        STANDARD_RAY_HIT_GROUP,
        hitProgramCount,
        STANDARD_RAY_HIT_GROUP,
        ray,
        payload,
    );

    si.hit = payload.hit;
    if (si.hit) {
		si.p = payload.hitPoint;
        si.n = payload.normal;
        si.shadingNormal = payload.shadingNormal;
        si.wo = -normalize(ray.Direction);
        LambertianBRDF bxdf;
        si.brdf = bxdf.Sample_f(si.wo, si.wi, float2(nextRand(randSeed), nextRand(randSeed)), si.pdf, gDiffuseColor[pixelIndex].rgb);
		si.directL = gDirectL[pixelIndex];
        // TODO: add emissive.
        // Radiance emitted by emissive objects.
		si.Le = float(0.f);
        si.brdfProbability = gBRDFProbability[pixelIndex].x;
    } else {
        // Radiance emitted by environment lights.
        si.Le = gDirectL[pixelIndex].xyz;
    }
}

[shader("closesthit")]
void DLClosestHit(inout DLRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    VertexOut vsOut = getVertexAttributes(PrimitiveIndex(), attributes);
    ShadingData shadingData = prepareShadingData(vsOut, gMaterial, gCamera.posW, 0);

    Interaction it;
    it.p = shadingData.posW;
    it.n = vsOut.normalW;
    it.shadingNormal = shadingData.N;
    // TODO: when implementing participating media, determine whether this is surface or medium.
    it.isSurfaceInteraction = true;
    it.wo = -normalize(WorldRayDirection());
    // TODO: handle media.
    bool handleMedia = false;
	float brdfProbability = getBRDFProbability(gMaterial, shadingData.V, it.shadingNormal);
    float3 L = UniformSampleOneLight(it, shadingData, payload.randSeed, brdfProbability, handleMedia);
    gDirectL[payload.pixelIndex] = L;
    gBRDFProbability[payload.pixelIndex] = float3(brdfProbability, brdfProbability, brdfProbability);

	// TODO: if surface is area light, sample emitted radiance.

	gDiffuseColor[payload.pixelIndex] = float4(shadingData.diffuse, shadingData.opacity);

    payload.hitPoint = vsOut.posW;
    payload.normal = vsOut.normalW;
    payload.shadingNormal = shadingData.N;
    payload.hit = true;
}

[shader("anyhit")]
void DLAnyHit(inout DLRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    if (alphaTestFails(attributes)) {
        IgnoreHit();
    }
}

[shader("miss")]
void DLMiss(inout DLRayPayload payload) {
	float2 envMapDimensions;
	gEnvMap.GetDimensions(envMapDimensions.x, envMapDimensions.y);

	float2 uv = WorldToLatitudeLongitude(WorldRayDirection());
    gDirectL[payload.pixelIndex] = gEnvMap[uint2(uv * envMapDimensions)].rgb;

    payload.hit = false;
}

float3 Li2(RayDesc ray, uint randSeed, uint2 pixelIndex, int depth, int maxDepth) {
    float3 L = float3(0.f);
    SurfaceInteraction si;
    spawnRay(ray, si, randSeed, pixelIndex);
    if (!si.hasHit()) {
        if (depth == 0) {
            L += si.Le;
        }
        return L;
    }
    float3 wo = si.wo;
    L += si.Le;
    if (gLightsCount > 0) {
        L += si.directL;
    }
    return L;
}

float3 Li1(RayDesc ray, uint randSeed, uint2 pixelIndex, int depth, int maxDepth) {
    float3 L = float3(0.f);
    SurfaceInteraction si;
    spawnRay(ray, si, randSeed, pixelIndex);
    if (!si.hasHit()) {
        if (depth == 0) {
            L += si.Le;
        }
        return L;
    }
    float3 wo = si.wo;
    L += si.Le;
    if (gLightsCount > 0) {
        L += si.directL;
    }
    if (depth+1 < maxDepth && nextRand(randSeed) < si.brdfProbability) {
        L += SpecularReflect2(ray, si, randSeed, pixelIndex, depth, maxDepth);
    }
    return L;
}

float3 SpecularReflect2(
    // TODO: should be RayDifferential.
    RayDesc ray,
    SurfaceInteraction si,
    uint randSeed,
    uint2 pixelIndex,
    int depth,
    int maxDepth
) {
    float3 wo = si.wo;
    float3 wi;
    float pdf;

    SpecularBRDF specularBRDF;
    // TODO: set somewhere else.
    specularBRDF.R = float3(1.f, 1.f, 1.f); 
    float3 f = specularBRDF.Sample_f(wo, wi, pdf);

    float3 ns = si.shadingNormal;
    if (pdf > 0 && !IsBlack(f) && abs(dot(wi, ns)) != 0) {
        RayDesc rd;
        rd.Origin = si.p;
        rd.Direction = wi;
        rd.TMin = 0.0f;
        rd.TMax = 1e+38f;
        return f * Li2(rd, randSeed, pixelIndex, depth+1, maxDepth) * abs(dot(wi, ns)) / pdf;
    } else {
        return float3(0.f, 0.f, 0.f);
    }
}

float3 SpecularReflect(
    // TODO: should be RayDifferential.
    RayDesc ray,
    SurfaceInteraction si,
    uint randSeed,
    uint2 pixelIndex,
    int depth,
    int maxDepth
) {
    float3 wo = si.wo;
    float3 wi;
    float pdf;

    SpecularBRDF specularBRDF;
    // TODO: set somewhere else.
    specularBRDF.R = float3(1.f, 1.f, 1.f); 
    float3 f = specularBRDF.Sample_f(wo, wi, pdf);

    float3 ns = si.shadingNormal;
    if (pdf > 0 && !IsBlack(f) && abs(dot(wi, ns)) != 0) {
        RayDesc rd;
        rd.Origin = si.p;
        rd.Direction = wi;
        rd.TMin = 0.0f;
        rd.TMax = 1e+38f;
        // TODO: compute differentials.

        // Compute sum term of Monte Carlo estimator of scattering equation. The product of the
        // BRDF f and the incident radiance Li gives the fraction of incident light that will get
        // reflected. The AbsDot(wi, ns) = cos(wi, ns) factor places the area differential on the
        // surface (the area differential dA is originally perpendicular to the wi solid angle).
        // return f * Li(rd, randSeed, pixelIndex, depth+1, maxDepth) * abs(dot(wi, ns)) / pdf;
        return f * Li1(rd, randSeed, pixelIndex, depth+1, maxDepth) * abs(dot(wi, ns)) / pdf;
    } else {
        return float3(0.f, 0.f, 0.f);
    }
}

struct DirectLightingIntegrator {
	int maxDepth;

	float3 Li(RayDesc ray, uint randSeed, uint2 pixelIndex, int depth) {
		// Radiance.
        float3 L = float3(0.f);

		SurfaceInteraction si;
		spawnRay(ray, si, randSeed, pixelIndex);
		if (!si.hasHit()) {
            // The ray escapes the scene bounds without having hit anything. Add
            // radiance emitted by environment lights. Light::Le is implemented
            // only by InfiniteAreaLight; the rest return black.
            L += si.Le;

			return L;
		}

		float3 wo = si.wo;

		// If the intersected object is emissive (an area light, for example), it contributes to the
    	// radiance carried by the ray.
		L += si.Le;

		if (gLightsCount > 0) {
			// TODO: LightStrategy::UniformSampleAll.
			L += si.directL;
		}

		if (depth+1 < maxDepth && nextRand(randSeed) < si.brdfProbability) {
			// Trace rays recursively for specular reflection and transmission. In general, the direct
			// lighting integrator estimates incident radiance using samples from light sources that
			// illuminate the surface directly. But in order for a surface with a (perfect) specular
			// BDRF to reflect the image of nearby objects, the integrator needs to trace and accumulate
			// radiance that bounces off of those objects in the direction of perfect specular reflection
			// toward the intersection point.

			// TODO: call SpecularTransmit.
            L += SpecularReflect(ray, si, randSeed, pixelIndex, depth, maxDepth);
		}

        return L;
	}
};