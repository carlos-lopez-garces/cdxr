RWTexture2D<float4> gDiffuseColor;
RWTexture2D<float3> gDirectL;
RWTexture2D<float3> gLe;
RWTexture2D<float3> gWo;
RWTexture2D<float3> gWi;
RWTexture2D<float3> gBRDF;
RWTexture2D<float> gPDF;
// Environment map;
Texture2D<float4> gEnvMap;

struct PTRayPayload {
    uint randSeed;
    float3 shadingNormal;
    float3 normal;
    float3 hitPoint;
    uint2 pixelIndex;
    bool hit;
};

void spawnRay(RayDesc ray, inout SurfaceInteraction si, uint randSeed, uint2 pixelIndex) {
    PTRayPayload payload;
    payload.randSeed = randSeed;
    payload.pixelIndex = pixelIndex;
    payload.hit = false;

    TraceRay(
        gRtScene,
        RAY_FLAG_CULL_BACK_FACING_TRIANGLES,
        0xFF,
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
        si.p = payload.hitPoint;
        si.n = payload.normal;
        si.shadingNormal = payload.shadingNormal;
        si.wo = gWo[pixelIndex];
        si.wi = gWi[pixelIndex];
        si.brdf = gBRDF[pixelIndex];
        si.pdf = gPDF[pixelIndex];
        si.directL = gDirectL[pixelIndex].xyz;
    } else {
        si.Le = gDirectL[pixelIndex].xyz;
    }
}

[shader("closesthit")]
void PTClosestHit(inout PTRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    VertexOut vsOut = getVertexAttributes(PrimitiveIndex(), attributes);

    // PrimitiveIndex() is an object introspection intrinsic that returns
    // the identifier of the current primitive.
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
    float3 L = UniformSampleOneLight(it, shadingData, payload.randSeed, handleMedia);
    gDirectL[payload.pixelIndex] = L;

    gDiffuseColor[payload.pixelIndex] = float4(shadingData.diffuse, shadingData.opacity);

    LambertianBRDF diffuseBRDF;
    gBRDF[payload.pixelIndex] = diffuseBRDF.Sample_f(
        it.wo,
        it.wi,
        float2(nextRand(payload.randSeed), nextRand(payload.randSeed)),
        it.pdf,
        gDiffuseColor[payload.pixelIndex].rgb
    );

    SpecularBRDF specularBRDF;
    // TODO: specify somewhere else.
    specularBRDF.R = float3(1.f, 1.f, 1.f);
    gBRDF[payload.pixelIndex] = specularBRDF.Sample_f(it.wo, it.wi, it.pdf);

    gWo[payload.pixelIndex] = it.wo;
    gWi[payload.pixelIndex] = it.wi;
    gPDF[payload.pixelIndex] = it.pdf;

    payload.hitPoint = vsOut.posW;
    payload.normal = vsOut.normalW;
    // shadingData.N is shading normal.
    payload.shadingNormal = shadingData.N;

    payload.hit = true;
}

[shader("anyhit")]
void PTAnyHit(inout PTRayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    if (alphaTestFails(attributes)) {
        IgnoreHit();
    }
}

[shader("miss")]
void PTMiss(inout PTRayPayload payload) {
	float2 envMapDimensions;
	gEnvMap.GetDimensions(envMapDimensions.x, envMapDimensions.y);

	float2 uv = WorldToLatitudeLongitude(WorldRayDirection());
    gDirectL[payload.pixelIndex] = gEnvMap[uint2(uv * envMapDimensions)].rgb;

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
        float3 L = float3(0.f);

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
            // Find next path vertex and accumulate contribution.

            // Intersect ray with scene to find next path vertex.
            SurfaceInteraction si;
            spawnRay(ray, si, randSeed, pixelIndex);
            bool foundIntersection = si.hasHit();

            // Possibly add emitted light at intersection.
            if (bounces == 0 || specularBounce) {
                // Add emitted light at path vertex or from the environment.
                //
                // When bounces = 0, this segment of the path starts directly at the camera.
                //
                // When specularBounce = true, the last segment of the path ended at a surface of
                // specular BSDF.

                if (foundIntersection) {
                    // TODO: sample emitted radiance if the light source is an area light.
                } else {
                    // The camera ray escaped out into the environment. Add the radiance contributions of
                    // infinite area lights (environment maps).
                    // TODO: sample environment map.
                    L += beta * si.Le;
                }
            }

            if (!foundIntersection || bounces >= maxDepth) {
                // When no intersection was found, the ray escaped out into the environment.
                // Reaching the established maximum number of bounces also terminates path sampling.
                break;
            }
            
            // TODO: handle media boundaries that don't have BSDFs.

            // Place the i+1th vertex of the path at a light source by sampling a point on one of them.
            // Compute the radiance contribution of the ith vertex (the current intersection) as a resut
            // of direct lighting from the chosen light source.
            L += beta * si.directL;

            float3 wo = -ray.Direction;
            float3 wi = si.wi;
            float pdf = si.pdf;
            float3 f = si.brdf;
            if (IsBlack(f) || pdf == 0.0f) {
                break;
            }

            // Add throughput weight at current vertex. The |cos(wi, si.shadingNormal)| factor is the one from the
            // energy balance form of the LTE and computes the component of irradiance that is perpendicular to
            // the surface at point si.p.
            beta *= f * abs(dot(wi, si.shadingNormal)) / pdf;

            // TODO: is this a specular bounce?
            specularBounce = false;

            // CPBRT spawns the ray here, but here we do it at the beginning of the loop.
            ray.Origin = offsetRayOrigin(si.p, si.shadingNormal);
            ray.Direction = wi;

            // Terminate path probabilistically via Russian Roulette.
            if (bounces > gMinBouncesBeforeRussianRoulette) {
                float q = max(0.05, 1 - beta.y);
                if (nextRand(randSeed) < q) {
                    break;
                }
                beta /= 1 - q;

                // (Relative) luminance Y is 0-1 luminance normalized to [0.0, 1.0]. The relative luminance of an RGB
                // color is a grayscale color and is obtained via dot product with a constant vector that has a
                // higher green component because that's the color that the retina perceives the most.
                // Defined in HostDeviceSharedCode.h.
                //
                // The probability of termination is inversely proportional to the current path throughput
                // beta. The smaller beta is at this vertex of the path, the smaller the contributions of
                // subsequent vertices are made (because light coming from subsequent vertices will necessarily
                // pass through this vertex and be subject to its BSDF; see the beta multiplication). A higher
                // probability of termination is desirable because path samples whose estimates contribute little
                // introduce variance in the total estimate of L.
                // float rrPdf = min(0.95f, luminance(beta));
                // // float q = max(0.05, 1 - beta.y);
                // if (rrPdf < nextRand(randSeed) /*nextRand(randSeed) < q*/) {
                //     // At least 0.05 probability of terminating.
                //     //
                //     // Warning: terminating paths increases the variance of the estimator.
                //     break;
                // } else {
                //     // Increase throughput, thereby decreasing the probability of terminating?
                //     beta /= rrPdf;
                //     // beta /= 1 - q;
                // }
            }
        }

        return L;
	}
};