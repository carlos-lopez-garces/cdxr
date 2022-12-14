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

    float3 wi = float3(0.f);
    float lightPdf = 0.f;
    float scatteringPdf = 0.f;
    VisibilityTester visibility;
    float3 diffuseLi = float3(0.f);
    float3 specularLi = float3(0.f);
    Sample_Li(light, it, diffuseLi, specularLi, wi, lightPdf, visibility, shadingData);
    // diffuseLi = specularLi typically, nut for light probes, the diffuse and specular
    // components are different.
    float3 Li = diffuseLi; // + specularLi;

    if (lightPdf > 0.f && !IsBlack(Li)) {
        float3 f = float3(0.f);

        // Evaluate BSDF for sampled incident direction.
        if (it.IsSurfaceInteraction()) {
            // TODO: other BRDFs.
            // Radiance is measured with respect to an area differential that is orthogonal
            // to the direction of incidence. To actually place this area differential on the
            // surface, the scattering equation includes the cosine of the theta angle as a factor,
            // measured from the surface normal to the direction of incidence).
            f = it.bsdf.f(it.wo, wi, it.pixelIndex) * saturate(dot(wi, it.shadingNormal));
            scatteringPdf = it.bsdf.Pdf(it.wo, wi);
        } else {
            // TODO: participating media.
        }

        if (!IsBlack(f)) {
            // The surface or medium reflects light.

            // Compute effect of visibility for light source sample.
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