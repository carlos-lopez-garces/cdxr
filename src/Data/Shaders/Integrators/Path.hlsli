struct PTRayPayload {
    uint randSeed;
    float3 shadingNormal;
    float3 normal;
    float3 hitPoint;
    uint2 pixelIndex;
    bool hit;
};

RWTexture2D<float4> gDiffuseBRDF;
// DEBUG: the texture created by the resource manager is not being bound to this variable.
RWTexture2D<float4> gDirectLightingRadiance;
RWTexture2D<float4> gSpecularBRDF;
// Environment map;
Texture2D<float4> gEnvMap;
Texture2D<float4> gMatDif;

void spawnRay(RayDesc ray, inout SurfaceInteraction si, uint randSeed, uint2 pixelIndex) {
    PTRayPayload payload;
    payload.randSeed = randSeed;
    payload.pixelIndex = pixelIndex;
    payload.hit = false;

    TraceRay(
        gRtScene,
        RAY_FLAG_NONE,
        0xFF,
        // Hit group #1.
        STANDARD_RAY_HIT_GROUP,
        // hitProgramCount is supplied by the framework and is the number of hit groups that exist.
        hitProgramCount,
        // Miss shader?
        STANDARD_RAY_HIT_GROUP,
        ray,
        payload,
    );

    si.hit = payload.hit;
    if (si.hit) {
        si.shadingNormal = payload.shadingNormal;
        si.p = payload.hitPoint;
        si.n = payload.normal;

        // TODO: use CosineSampleHemisphere.
        // A different wi is used in EstimateDirect, the one pointing directly to the chosen light.
        si.wi = normalize(getCosHemisphereSample(randSeed, payload.shadingNormal));
        if (si.wi.z < 0) {
            si.wi.z *= -1;
        }
        // DEBUG: gDiffuseBRDF[pixelIndex].xyz comes indeed from the closesthit shader.
        si.diffuseBRDF = gDiffuseBRDF[pixelIndex].xyz;
        // DEBUG. gDiffuseBRDF[pixelIndex].xyz is black.
        // si.diffuseBRDF = float3(0.3, 0.4, 0.5);
        // si.diffusePdf = abs(dot(payload.shadingNormal, si.wi)) * M_1_PI;
        float3 wo = normalize(si.p - ray.Origin);
        si.diffusePdf = SameHemisphere(wo, si.wi) ? AbsCosTheta(si.wi) * M_1_PI : 0.f;

        // DEBUG: pixels show the color set/returned in si.diffuseLightIntensity.
        // DEBUG: whatever is in gDirectLightingRadiance is indeed seen by the caller in si.diffuseLightIntensity.
        // gDirectLightingRadiance[pixelIndex] = float4(0.5, 0.9, 0.7, 1.0);
        si.diffuseLightIntensity = gDirectLightingRadiance[pixelIndex].xyz;
        si.diffuseColor = gMatDif[pixelIndex].xyz;
    } else {
        si.diffuseLightIntensity = float4(0.6f, 0.355f, 0.8f, 1.0f).xyz;
    }
}

[shader("closesthit")]
void PTClosestHit(inout PTRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    VertexOut vsOut = getVertexAttributes(PrimitiveIndex(), attributes);

    // PrimitiveIndex() is an object introspection intrinsic that returns
    // the identifier of the current primitive.
    ShadingData shadingData = getShadingData(PrimitiveIndex(), attributes);

    Interaction it;
    it.p = shadingData.posW;
    it.shadingNormal = shadingData.N;
    // TODO: when implementing participating media, determine whether this is surface or medium.
    it.isSurfaceInteraction = true;
    it.wo = -normalize(it.p - WorldRayOrigin());
    // TODO: handle media.
    bool handleMedia = false;
    float3 L = UniformSampleOneLight(it, shadingData, payload.randSeed, handleMedia);
    gDirectLightingRadiance[payload.pixelIndex] = float4(L, 1.0);



    int lightToSample = min(int(nextRand(payload.randSeed) * gLightsCount), gLightsCount - 1);
	LightSample lightSample;
	if (gLights[lightToSample].type == LightDirectional) {
		lightSample = evalDirectionalLight(gLights[lightToSample], shadingData.posW);
    } else {
		lightSample = evalPointLight(gLights[lightToSample], shadingData.posW);
    }
	// float3 directionToLight = normalize(lightSample.L);
    // gDirectLightingRadiance[payload.pixelIndex] = float4(lightSample.diffuse, 1.0); 
    // gDirectLightingRadiance[payload.pixelIndex] = float4(0.0f,1.0f,1.0f, 1.0f);
	// float distanceToLight = length(lightSample.posW - shadingData.posW);

    // shadingData.N is shading normal.
    payload.shadingNormal = shadingData.N;
    //payload.hitPoint = shadingData.posW;
    payload.hitPoint = vsOut.posW;
    payload.normal = vsOut.normalW;

    gDiffuseBRDF[payload.pixelIndex] = float4(evalDiffuseLambertBrdf(shadingData, lightSample), 0.0);
    // DEBUG.
    // gDiffuseBRDF[payload.pixelIndex] = float4(0.7, 0.8, 0.9, 1.0); 

    payload.hit = true;
}

[shader("anyhit")]
void PTAnyHit(inout PTRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    if(alphaTestFails(attributes)) {
        IgnoreHit();
    }
}

[shader("miss")]
void PTMiss(inout PTRayPayload payload) {
	float2 envMapDimensions;
	gEnvMap.GetDimensions(envMapDimensions.x, envMapDimensions.y);

	float2 uv = WorldToLatitudeLongitude(WorldRayDirection());

    // payload.sampledInterreflectionColor = float4(gEnvMap[uint2(uv * envMapDimensions)].rgb, 1.0f);
    gDirectLightingRadiance[payload.pixelIndex] = float4(gEnvMap[uint2(uv * envMapDimensions)].rgb, 1.0f);
    // gDirectLightingRadiance[payload.pixelIndex] = float4(1.0f,0.0f,1.0f, 1.0f);
    // DEBUG: The miss shader doesn't get to execute. Regions of the scene where the environment map should
    // be visible, the pixel color returned is the debug one set in the closesthit shader.
    // gDirectLightingRadiance[payload.pixelIndex] = float4(0.6f, 0.355f, 0.8f, 1.0f);
    payload.hit = false;
}

// PathIntegrator evaluates the path integral form of the light transport equation, or LTE (its other
// forms, the energy balance form and its surface (3-point) form are much more difficult to
// evaluate).
//
// The LTE describes the equilibrium distribution of radiance in a scene (i.e. this distribution doesn't
// change over time; radiance is assumed to have "settled"). The LTE is evaluated at points on surfaces
// and it gives the total reflected radiance Lo at each of those points.
//
// Lo(p,wo) = Le(p,wo) + Int_{S^2}{f(p,wo,wi)Lo(t(p,wi),-wi)|cos(thetai)|}dwi   [Energy balance form of the LTE.]
//
// where f is the BSDF of the surface. Obseve that the LTE integrates exitant radiance Lo over the sphere
// of directions around p, giving Lo a recursive definition. There's another form of the LTE, the surface
// or 3-point form, denoted Lo(p' => p), that integrates Lo(p" => p') over all points p" on all surfaces
// of the scene for a given point p' being shaded, but it also has a recursive definition.
struct PathIntegrator {
    int maxDepth;

	float3 Li(RayDesc ray, uint randSeed, uint2 pixelIndex) {
		// Radiance.
        float3 L = float3(0.0f);

        // Throughput weight. The throughput function T(\bar{p}_n) of a path of length n gives the fraction of 
        // radiance that ultimately arrives at the first path vertex (i.e. on the lens of the camera)
        // after scattering takes place at each of the path's vertices. T(\bar{p}_n) multiplies the product of
        // the BSDF and the geometric coupling factor G(p <-> p') at each of the n-1 vertices of the path that
        // follow the first one.
        //
        // The geometric coupling factor multiplies the |cos(theta)| term of the energy balance equation, the
        // Jacobian determinant that relates solid angle to area (necessary to transform the integral over
        // a set of directions of the energy balance form to an integral over surface area of the surface form,
        // which ultimately leads to the path form of the LTE), and a 0-1 visibility function that determines if
        // 2 points are mutually visible, V(p <-> p').
        //
        // Here, we set aside the Jacobian determinant and the visibility testing function of the geometric
        // coupling factor G(p <-> p') and keep only the |cos(theta)| factor to define a throughput weight:
        // the product of the BSDF at the vertex f(p_j+1, p_j, p+j-1) and the |cos(theta)| factor, divided
        // by their sampling pdfs (computed and returned by the BSDF). The visibility testing function V(p <-> p')
        // is not needed because ray casting inherently finds points that the current vertex can see (except
        // when the ray escapes into the environment, in which case we sample the environment map and terminate).
        //
        // TODO: what happened to the Jacobian determinant?
        float3 beta = float3(1.0f, 1.0f, 1.0f);

        bool specularBounce = false;

        for (int bounces = 0; ; ++bounces) {
            SurfaceInteraction si;

            // TODO: Handle media boundaries that don't have BSDFs.
            
            // TODO: Revisit. Not in cpbrt.
            // L += beta * si.emissive;

            // TODO: Revisit. Not in cpbrt.
            // Direct illumination.
            // gLightsCount and getLightData() are automatically imported by Falcor.
            // int lightToSample = min(int(nextRand(randSeed) * gLightsCount), gLightsCount - 1);
            // L += beta * si.color.rgb * sampleLight(lightToSample, si.p, si.shadingNormal, true, gTMin);

            // shootGIRay(si, randSeed, true);
            // DEBUG: where are primary rays pointing? the closesthit shader executes for regions where the
            // environment map should be visible.
            // return ray.Direction;
            spawnRay(ray, si, randSeed, pixelIndex);
            // return ray.Origin;

            // DEBUG: most pixels are some shade of green, except vases, which are black.
            // return si.p;
            // return si.shadingNormal;
            bool foundIntersection = si.hasHit();
            // return si.hasHit() ? float3(1.0f, 0.0f, 0.0f) : float3(0.0f, 1.0f, 0.0f);

            // DEBUG.
            // return si.diffuseLightIntensity;

            if (bounces == 0 || specularBounce) {
                if (foundIntersection) {
                    // TODO: sample emitted radiance if the light source is an area light.
                } else {
                    // TODO: Sample environment map.
                    // L += beta * si.diffuseLightIntensity;
                }
            }

            if (!foundIntersection || bounces >= maxDepth) {
                // When no intersection was found, the ray escaped out into the environment.
                // Reaching the established maximum number of bounces also terminates path sampling.

                // DEBUG.
                // L = float3(0.0f, 1.0f, 0.0f);
                break;
            }

            // Place the i+1th vertex of the path at a light source by sampling a point on one of them.
            // Compute the radiance contribution of the ith vertex (the current intersection) as a resut
            // of direct lighting from the chosen light source.
            L += beta * si.diffuseLightIntensity;

            float3 wo = -ray.Direction;
            float3 wi = si.wi;
            float pdf = si.diffusePdf;
            float3 f = si.diffuseBRDF;
            // DEBUG.
            // f = si.diffuseColor;
            // DEBUG.
            // return f;
            if (IsBlack(f) || pdf == 0.0f) {
                break;
            }

            // DEBUG.
            // return beta;

            // Add throughput weight at current vertex. The |cos(wi, si.shadingNormal)| factor is the one from the
            // energy balance form of the LTE and computes the component of irradiance that is perpendicular to
            // the surface at point si.p.
            beta *= f * abs(dot(wi, si.shadingNormal)) / pdf;

            // DEBUG.
            // return si.shadingNormal;

            // TODO: Is this a specular bounce?
            specularBounce = false;

            // CPBRT spawns the ray here, but here we do it at the beginning of the loop.
            // ray = ...
            ray.Origin = offsetRayOrigin(si.p, si.shadingNormal);
            ray.Direction = wi;

            // Terminate path probabilistically via Russian Roulette.
            if (bounces > gMinBouncesBeforeRussianRoulette) {
                // (Relative) luminance Y is 0-1 luminance normalized to [0.0, 1.0]. The relative luminance of an RGB
                // color is a grayscale color and is obtained via dot product with a constant vector that has a
                // higher green component because that's the color that the retina perceives the most.
                // Defined in HostDeviceSharedCode.h.
                //
                // The probability of termination  is inversely proportional to the current path throughput
                // beta. The smaller beta is at this vertex of the path, the smaller the contributions of
                // subsequent vertices are made (because light coming from subsequent vertices will necessarily
                // pass through this vertex and be subject to its BSDF; see the beta multiplication). A higher
                // probability of termination is desirable because path samples whose estimates contribute little
                // introduce variance in the total estimate of L.
                float rrPdf = min(0.95f, luminance(beta));
                // float q = max(0.05, 1 - beta.y);
                if (rrPdf < nextRand(randSeed) /*nextRand(randSeed) < q*/) {
                    // At least 0.05 probability of terminating.
                    //
                    // Warning: terminating paths increases the variance of the estimator.
                    break;
                } else {
                    // Increase throughput, thereby decreasing the probability of terminating?
                    beta /= rrPdf;
                    // beta /= 1 - q;
                }
            }
        }

        return L;
	}
};