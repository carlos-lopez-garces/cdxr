struct SpecularBRDF {
    float3 R;

    // Computes the spectral distribution of a radiometric quantity over wavelength for an
    // arbitrary pair of outgoing and incident directions. Since there's no chance that an
    // arbitrary pair will satisfy the perfect reflection relation, the returned reflectance
    // is 0.
    float3 f(float3 wo, float3 wi) {
        // TODO: ?
        return R;
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