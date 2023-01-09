struct LambertianBRDF {
    // Should be ShadingData.diffuse.
    float3 R;

    float3 f(float3 wo, float3 wi) {
        return R * M_1_PI;
    }

    // Computes the spectral distribution of a radiometric quantity over wavelength in the
    // given outgoing direction, computing also the (possibly unique) corresponding incident
    // direction. Vectors wo and wi are expressed with respect to the local coordinate system.
    float3 Sample_f(
        float3 wo,
        inout float3 wi,
        float2 u,
        inout float pdf
    ) {
        // The incident direction wi corresponding to the outgoing direction wo may be any
        // one on the hemisphere centered at the point u and on the side of the surface where
        // wo exits (which isn't always the side of the surface's normal). This incident direction
        // wi is sampled from a cosine-weighted distribution, which assigns a higher probability
        // to directions at the top of the hemisphere than those at the bottom (why is this
        // desirable?).
        //
        // A different wi is used in EstimateDirect, the one pointing directly to the chosen light.
        // si.wi = normalize(getCosHemisphereSample(randSeed, payload.shadingNormal));
        wi = CosineSampleHemisphere(u);
        if (wo.z < 0) {
            // CosineSampleHemisphere samples the hemisphere on the normal's side. When the outgoing
            // direction wo lies on the hemisphere opposite to the normal, wi will have been sampled
            // from the wrong hemisphere. Bring it to wo's side.
            wi.z *= -1;
        }

        // Computes the PDF with which the incident direction wi was sampled. This PDF is of a 
        // cosine-weighted distribution: p(w)=r*cos(theta)/pi, where r=1 is the radius
        // of the unit hemisphere and theta is measured from the hemisphere's axis.
        pdf = Pdf(wo, wi);

        // TODO.
        return f(wo, wi);
    }

    // Computes the PDF with which Sample_f samples the incident direction wi. This PDF is of a
    // cosine-weighted distribution: p(w)=r*cos(theta)/pi, where r=1 is the radius of the unit hemisphere
    // and theta is measured from the hemisphere's axis.
    float Pdf(float3 wo, float3 wi) {
        return SameHemisphere(wo, wi) ? AbsCosTheta(wi) * M_1_PI : 0.f;
    }
};