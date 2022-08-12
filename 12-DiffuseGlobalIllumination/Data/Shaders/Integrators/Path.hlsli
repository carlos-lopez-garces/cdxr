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

	float3 Li(SurfaceInteraction si, uint randSeed) {
		// Radiance.
        float3 L = float3(0.0f, 0.0f, 0.0f);

        // Throughput weight. The throughput function T(\bar{p}_n) of a path of length n gives the fraction of 
        // radiance that ultimately arrives at the first path vertex (i.e. on the lens of the camera)
        // after scattering takes places at each of the path's vertices. T(\bar{p}_n) multiplies the product of
        // the BSDF and the geometric coupling factor G(p <-> p') at each of the n-1 vertices of the path that
        // follow the first one.
        //
        // The geometric coupling factor multiplies the |cos(theta)| term of the energy balance equation, the
        // Jacobian determinant that relates solid angle to area (necessary to transform the integral over
        // a set of directions of the energy balance form to an integral over surface area of the surface form,
        // which ultimately leads to the path form of the LTE), and 0-1 visibility function that determines if
        // 2 points are mutually visible, V(p <-> p').
        //
        // Here, we set aside the Jacobian determinant and the visibility testing function of the geometric
        // coupling factor G(p <-> p') and keep only the |cos(theta)| factor to define a throughput weight:
        // the product of the BSDF at the vertex f(p_j+1, p_j, p+j-1) and the |cos(theta)| factor, divided
        // by their sampling pdfs (computed and returned by the BSDF). The visibility testing function V(p -> p')
        // is not needed because ray casting inherently finds points that the current vertex can see (except
        // when the ray escapes into the environment, in which cas we sample the environment map and terminate).
        //
        // TODO: what happened to the Jacobian determinant?
        float3 beta = float3(1.0f, 1.0f, 1.0f);

        bool specularBounce = false;

        for (int bounces = 0; ; ++bounces) {
            // TODO: Revisit. Not in cpbrt.
            L += beta * si.emissive;

            // TODO: Revisit. Not in cpbrt.
            // Direct illumination.
            // gLightsCount and getLightData() are automatically imported by Falcor.
            int lightToSample = min(int(nextRand(randSeed) * gLightsCount), gLightsCount - 1);
            L += beta * si.color.rgb * sampleLight(lightToSample, si.p, si.shadingNormal, true, gTMin);

            shootGIRay(si, randSeed, true);
            bool foundIntersection = si.hasHit();

            if (bounces == 0 || specularBounce) {
                if (foundIntersection) {
                    // TODO
                } else {
                    // TODO: Sample environment map.
                }
            }

            if (!foundIntersection || bounces >= maxDepth) {
                // When no intersection was found, the ray escaped out into the environment.
                // Reaching the established maximum number of bounces also terminates path sampling.
                break;
            }

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
                if (rrPdf < nextRand(randSeed)) {
                    // At least 0.05 probability of terminating.
                    //
                    // Warning: terminating paths increases the variance of the estimator.
                    break;
                } else {
                    // Increase throughput, thereby decreasing the probability of terminating?
                    beta /= rrPdf;
                }
            }

            si.p = offsetRayOrigin(si.p, si.n);
        }

        return L;
	}
};