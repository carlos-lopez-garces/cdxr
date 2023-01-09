struct BSDF {
    // Geometric normal.
    float3 ng;

    // Orthonormal basis (ss, ts, ns) for shading coordinate system. All are coordinate
    // vectors relative to the world space basis.

    // Shading normal.
    float3 ns;
    // Primary tangent.
    float3 ss;
    // Secondary tangent.
    float3 ts;

    bool hasDiffuseBRDF = false;
    LambertianBRDF diffuseBRDF;

    bool hasSpecularBRDF = false;
    SpecularBRDF specularBRDF;

    int nBxDFs = 0;

    int NumComponents() {
        int num = 0;
        if (hasDiffuseBRDF) num++;
        if (hasSpecularBRDF) num++;
        return num;
    }

    // Change of coordinate from world space to shading space.
    float3 WorldToLocal(float3 v) {
        // TODO: explain; this is not the change-of-coordinate matrix I'm familiar
        // with or the change of basis.
        return float3(dot(v, ss), dot(v, ts), dot(v, ns));
    }

    // Change of coordinate from shading space to world space.
    float3 LocalToWorld(float3 v) {
        // TODO: explain; is this the inverse of WorldToLocal computed as the transpose
        // because it's orthogonal?
        return float3(
            ss.x * v.x + ts.x * v.y + ns.x * v.z,
            ss.y * v.x + ts.y * v.y + ns.y * v.z,
            ss.z * v.x + ts.z * v.y + ns.z * v.z
        );
    }

    float3 f(float3 woW, float3 wiW, float2 pixelIndex) {
        float3 wi = WorldToLocal(wiW);
        float3 wo = WorldToLocal(woW);

        // Determine whether the incident and outgoing direction vectors are on the same or
        // opposite hemispheres.
        bool reflect = dot(wiW, ng) * dot(woW, ng) > 0;

        float3 f = float3(0.f);

        // Evaluate only the BRDFs when incident and outgoing direction vectors are on the same hemisphere.
        // TODO: evaluate only the BTDFs when they are on opposite hemispheres.
        if (reflect && hasDiffuseBRDF) {
            f += diffuseBRDF.f(wo, wi, diffuseBRDF.R);
        }
        if (reflect && hasSpecularBRDF) {
            f += specularBRDF.f(wo, wi);
        }

        return f;
    }

    float Pdf(float3 woW, float3 wiW) {
        if (nBxDFs == 0) {
            return 0.f;
        }

        float3 wi = WorldToLocal(wiW);
        float3 wo = WorldToLocal(woW);
        if (wo.z == 0) {
            return 0.f;
        }

        float pdf = 0.f;
        // TODO: determine matching components using input requested type.
        int matchingComps = nBxDFs;
        if (hasDiffuseBRDF) {
            pdf += diffuseBRDF.Pdf(wo, wi);
        }
        if (hasSpecularBRDF) {
            pdf += specularBRDF.Pdf(wo, wi);
        }

        // The probability of sampling wi for a given wo is the average of the PDFs of all 
        // the BxDFs that match the input flags.
        return matchingComps > 0 ? pdf / matchingComps : 0.f;
    }
};

// Creates the BSDF at the surface-ray intersection point.
void ComputeScatteringFunctions(
    inout Interaction it,
    ShadingData shadingData,
    bool allowMultipleLobes
) {
    it.bsdf.ns = it.shadingNormal;
    it.bsdf.ng = it.n;
    it.bsdf.ss = float3(0.f);
    it.bsdf.ts = float3(0.f);
    CoordinateSystem(it.bsdf.ns, it.bsdf.ss, it.bsdf.ts);

    it.bsdf.hasDiffuseBRDF = false;
    if (!IsBlack(shadingData.diffuse)) {
        it.bsdf.hasDiffuseBRDF = true;
        it.bsdf.diffuseBRDF.R = shadingData.diffuse;
        it.bsdf.nBxDFs++;
    }

    it.bsdf.hasSpecularBRDF = false;
    if (!IsBlack(shadingData.specular)) {
        it.bsdf.hasSpecularBRDF = true;
        it.bsdf.specularBRDF.R = shadingData.specular;
        it.bsdf.nBxDFs++;
    }		
}