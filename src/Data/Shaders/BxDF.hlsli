#define BXDF_DIFFUSE 1
#define BXDF_SPECULAR 2

struct LambertianBRDF {
    float3 f(float3 wo, float3 wi, float3 diffuseColor) {
        return diffuseColor * M_1_PI;
    }

    // Computes the spectral distribution of a radiometric quantity over wavelength in the
    // given outgoing direction, computing also the (possibly unique) corresponding incident
    // direction. Vectors wo and wi are expressed with respect to the local coordinate system.
    float3 Sample_f(
        float3 wo,
        inout float3 wi,
        float2 u,
        inout float pdf,
        // TODO: don't pass this; instead create BxDF objects that contain that info.
        float3 diffuseColor
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
        if (wi.z < 0) {
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
        return f(wo, wi, diffuseColor);
    }

    // Computes the PDF with which Sample_f samples the incident direction wi. This PDF is of a
    // cosine-weighted distribution: p(w)=r*cos(theta)/pi, where r=1 is the radius of the unit hemisphere
    // and theta is measured from the hemisphere's axis.
    float Pdf(float3 wo, float3 wi) {
        return SameHemisphere(wo, wi) ? AbsCosTheta(wi) * M_1_PI : 0.f;
    }
};

struct SpecularBRDF {
    float3 R;

    // Computes the spectral distribution of a radiometric quantity over wavelength for an
    // arbitrary pair of outgoing and incident directions. Since there's no chance that an
    // arbitrary pair will satisfy the perfect reflection relation, the returned reflectance
    // is 0.
    float3 f(float wo, float wi) {
        // TODO: ?
        return float3(0.f);
    }

    // Samples the BRDF. The only possible incoming direction wi for the input outgoing wo
    // is its reflection about the surface normal. The normal vector doesn't need to be known
    // because it corresponds to the vertical axis in the reflection coordinate system.
    float3 Sample_f(
        float3 wo,
        inout float3 wi,
        inout float pdf
    ) {
        // Compute perfect specular reflection direction about the normal. The normal vector doesn't
        // need to be known because it corresponds to the vertical axis in the reflection coordinate
        // system.
        //
        // The shading coordinate system places the z axis along the surface normal at the shaded point.
        wi = float3(-wo.x, -wo.y, wo.z);
        
        // The perfect reflection direction wi is always sampled with probability 1.
        pdf = 1;

        return evaluateNoOpFresnel(CosTheta(wi)) * R / AbsCosTheta(wi);
    }

    // Evaluates the probability that incident direction wi gets sampled for the given outgoing
    // direction wo. Since there's virtually no chance that wi will be the perfect specular
    // reflection direction of wo obtained at random, the probability is 0.
    float Pdf(float3 wo, float3 wi) {
        return 0;
    }
};