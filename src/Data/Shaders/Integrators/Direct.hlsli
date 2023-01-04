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
RWTexture2D<float4> gDirectLightingRadiance;
RWTexture2D<float4> gSpecularBRDF;

// Environment map;
Texture2D<float4> gEnvMap;
Texture2D<float4> gMatDif;

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
		si.Le = gLe[pixelIndex];
    } else {
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

struct DirectLightingIntegrator {
	int maxDepth;

	float3 Li(RayDesc ray, uint randSeed, uint2 pixelIndex, int depth) {
		// Radiance.
        float3 L = float3(0.f);

		SurfaceInteraction si;
		spawnRay(ray, si, randSeed, pixelIndex);
		if (!si.hasHit()) {
			// TODO: add all lights' Le; si.Le is only of the environment map.
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

		if (depth+1 < maxDepth) {
			// Trace rays recursively for specular reflection and transmission. In general, the direct
			// lighting integrator estimates incident radiance using samples from light sources that
			// illuminate the surface directly. But in order for a surface with a (perfect) specular
			// BDRF to reflect the image of nearby objects, the integrator needs to trace and accumulate
			// radiance that bounces off of those objects in the direction of perfect specular reflection
			// toward the intersection point.

			// TODO: call SpecularReflect and SpecularTransmit.
		}

        return L;
	}
};