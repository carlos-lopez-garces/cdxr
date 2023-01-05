float3 EstimateDirect(
    Interaction it,
    float2 uScattering,
    int lightNum,
    float2 uLight,
    ShadingData shadingData,
    float brdfProbability,
    bool handleMedia
) {
    // Radiance.
    float3 Ld = float3(0.0f);

    LightData light = gLights[lightNum];

    float3 Li = float3(0.f);
    float3 wi = float3(0.f);
    float lightPdf = 0.f;
    float scatteringPdf = 0.f;
	LightSample lightSample;
    VisibilityTester visibility;
	if (light.type == LightPoint) {
		lightSample = evalPointLight(light, it.p);

        // A PointLight has a delta distribution of direction; it illuminates a given
        // point of incidence from a single direction with probability 1.
        lightPdf = 1.f;
        // Which is intensity * falloff.
        Li = lightSample.diffuse;

        visibility.n = it.n;
        visibility.p0 = it.p;
        visibility.p1 = lightSample.posW;
    } else if (light.type == LightDirectional) {
		lightSample = evalDirectionalLight(light, it.p);
        lightPdf = 1.f;
        // Which is equal to intensity.
        Li = lightSample.diffuse;

        // Place p1 outside the scene along the light source's direction. A distant
        // light doesn't emit radiance from any particular location, just along the
        // same direction.
        visibility.n = it.n;
        visibility.p0 = it.p;
        visibility.p1 = it.p + lightSample.L * (2 * 1e3f);
    } else {
        // TODO: area lights.
        return Ld;
    }
	wi = normalize(lightSample.L);
    if (lightPdf > 0.f && !IsBlack(Li)) {
        float3 f = float3(0.f);
        // Evaluate BSDF for sampled incident direction.
        if (it.IsSurfaceInteraction()) {
            // TODO: other BRDFs.
            // Radiance is measured with respect to an area differential that is orthogonal
            // to the direction of incidence. To actually place this area differential on the
            // surface, the scattering equation includes the cosine of the theta angle as a factor,
            // measured from the surface normal to the direction of incidence).
            if (uScattering.x < brdfProbability) {
            // if (gMaterial.specular.g > 0.5) {
                SpecularBRDF specularBRDF;
                // TODO: specify somewhere else.
                specularBRDF.R = shadingData.diffuse; //float3(1.f, 1.f, 1.f); 
                f = specularBRDF.f(it.wo, wi);
                scatteringPdf = specularBRDF.Pdf(it.wo, wi);
            } else {
                LambertianBRDF diffuseBRDF;
                f = diffuseBRDF.f(it.wo, wi, shadingData.diffuse) * abs(dot(wi, it.shadingNormal));
                scatteringPdf = diffuseBRDF.Pdf(it.wo, wi);
            }
        } else {
            // TODO: participating media.
        }

        if (!IsBlack(f)) {
            // The surface or medium reflects light.

            if (handleMedia) {
                // TODO: handle media.
            } else if (!visibility.Unoccluded()) {
                // The light source doesn't illuminate the surface from the sampled direction.
                Li = float3(0.f);
            }

            // Add light's contribution to reflected radiance.
            if (!IsBlack(Li)) {
                if (IsDeltaLight(light)) {
                    // The light source is described by a delta distribution, that is, it illuminates
                    // from a single direction with probability 1 and, therefore, the sample introduces
                    // no variance. Since there's no variance to reduce, there's no need for weighting
                    // the sample like multiple importance sampling does, so compute the standard Monte
                    // Carlo estimate for it and add its contribution.
                    Ld += f * Li / lightPdf;
                } else {
                    // TODO: non-delta lights, like area lights.
                }
            }
        }
    }

    if (!IsDeltaLight(light)) {
        // TODO: MIS for non-delta lights.
    }

    return Ld;
}

// Evaluates the direct lighting outgoing radiance / scattering equation at the
// intersection point by taking a single sample from a single light source chosen
// uniformly at random. 
float3 UniformSampleOneLight(
    Interaction it,
    ShadingData shadingData,
    uint randSeed,
    float brdfProbability,
    bool handleMedia
) {
    // Randomly choose single light to sample.
    int nLights = gLightsCount;
    if (nLights == 0) {
        return float3(0.f, 0.f, 0.f);
    }
    int lightNum = min(int(nextRand(randSeed) * nLights), nLights - 1);

    float2 uLight = float2(nextRand(randSeed), nextRand(randSeed));
    float2 uScattering = float2(nextRand(randSeed), nextRand(randSeed));

    return nLights * EstimateDirect(it, uScattering, lightNum, uLight, shadingData, brdfProbability, handleMedia);
}