// Torrance-Sparrow microfacet model. V-shaped cavities of symmetric microfacets with perfectly
// specular reflection. Only the microfacets with a normal equal to the half-angle of a pair of
// directions wo and wi reflect light. (Corresponds to MicrofacetReflection in PBRT.)
struct TorranceSparrowMicrofacetBRDF {
    // Single microfacet reflectance.
    float3 R;

    // Distribution of slope and orientation of V-shaped microfacets. The distribution function
    // gives the normalized differential area of microfacets with a given normal wh. Gives also
    // the geometric attenuation factor, GAF, that accounts for masking and shadowing. 
    GGXNormalDistribution distribution;

    // Fresnel reflectance. Evaluates the Fresnel reflectance equations that determine the 
    // fraction of light that is reflected (the rest is transmitted or absorbed).
    // TODO: associate Fresnel equation object.

    float3 f(float3 wo, float3 wi, Interaction it, ShadingData shadingData) {
        float cosThetaO = AbsCosTheta(wo);
        float cosThetaI = AbsCosTheta(wi);

        // Half-angle.
        float3 wh = wi + wo;

        // Edge cases: perfectly grazing incident or outgoing directions.
        if (cosThetaI == 0 || cosThetaO == 0) {
            return float3(0);
        }
        if (wh.x == 0 && wh.y == 0 && wh.z == 0) {
            return float3(0);
        }

        wh = normalize(wh);

        // Fresnel reflectance; fraction of incident light that gets reflected in the half-angle direction.
        // f1 = (1.0, 1.0, 1.0) as in Chris Wyman's schlickFresnel().
        float3 F = evaluateSchlickFresnel(
            shadingData.specular,
            1.f,
            dot(wi, FaceForward(wh, float3(0, 0, 1)))
        );

        return 
            R 
            * distribution.D(it.n, wh, shadingData.roughness)
            * distribution.G(it.n, wi, wo, shadingData.roughness)
            * F / (4 * cosThetaI * cosThetaO);
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
        return float3(0);
    }

    // Computes the PDF with which Sample_f samples the incident direction wi. This PDF is of a
    // cosine-weighted distribution: p(w)=r*cos(theta)/pi, where r=1 is the radius of the unit hemisphere
    // and theta is measured from the hemisphere's axis.
    float Pdf(float3 wo, float3 wi) {
        return 0;
    }
};