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

    bool hasAshikhminShirleyBRDF = false;
    AshikhminShirleyBRDF ashikhminShirleyBRDF;

    int nBxDFs = 0;

    int NumComponents() {
        int num = 0;
        if (hasDiffuseBRDF) num++;
        if (hasSpecularBRDF) num++;
        if (hasAshikhminShirleyBRDF) num++;
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
            f += diffuseBRDF.f(wo, wi);
        }
        if (reflect && hasSpecularBRDF) {
            f += specularBRDF.f(wo, wi);
        }
        if (reflect && hasAshikhminShirleyBRDF) {
            f += ashikhminShirleyBRDF.f(wo, wi);
        }

        return f;
    }

    float3 Sample_f(
        float3 woW,
        inout float3 wiW,
        float2 u,
        inout float pdf,
        inout float sampledType,
        float2 pixelIndex
    ) {
        // TODO: determine matching components based on input type requested.
        int matchingComps = NumComponents();
        int bxdfType;
        float2 uRemapped = u;
        if (matchingComps == 0) {
            pdf = 0.f;
            sampledType = BXDF_NONE;
            return float3(0.f);
        } else if (matchingComps == 1) {
            if (hasAshikhminShirleyBRDF) {
                bxdfType = BRDF_GLOSSY;
            } else {
                bxdfType = hasDiffuseBRDF ? BRDF_DIFFUSE : BRDF_SPECULAR;
            }
        } else {
            // Choose one of the matching component BxDFs uniformly at random. Call it k.
            int kthMatchingComp = min((int) floor(u.x * matchingComps), matchingComps - 1);
            bxdfType = kthMatchingComp == 0 ? BRDF_DIFFUSE : BRDF_SPECULAR;
            // The 2D sample u will be used for sampling the chosen BxDF, but the first of
            // its components, u[0], has already been used (for sampling the set of matching
            // BxDFs). Remap it to [0,1).
            // TODO: explain.
            uRemapped = float2(min(u.x * matchingComps - kthMatchingComp, ONE_MINUS_EPSILON), u.y);
        }

        // Sample chosen BxDF. We don't care about the returned radiometric spectrum f, only
        // about wi and pdf. The BSDF's radiometric spectrum corresponding to wi is computed
        // later.
        float3 wi;
        float3 wo = WorldToLocal(woW);
        if (wo.z == 0) {
            return float3(0.f);
        }
        pdf = 0;
        sampledType = (float) bxdfType;
        float3 f = float3(0.f);
        if (bxdfType == BRDF_GLOSSY) {
            f = ashikhminShirleyBRDF.Sample_f(wo, wi, uRemapped, pdf);
        } else if (bxdfType == BRDF_DIFFUSE) {
            f = diffuseBRDF.Sample_f(wo, wi, uRemapped, pdf);
        }
        else {
            f = specularBRDF.Sample_f(wo, wi, pdf);
        }
        if (pdf == 0) {
            sampledType = BXDF_NONE;
            return float3(0.f);
        }
        wiW = LocalToWorld(wi);

        // At this point, pdf stores the probability with which wi was obtained after
        // sampling the chosen BxDF. But when we chose this BxDF at random, we were actually
        // sampling the overall set of directions represented by all the matching BxDFs. So
        // wi wasn't really sampled from the chosen BxDFs's distribution, it was sampled from
        // the overall distribution of the matching BxDFs, whose PDF is the average of all the
        // PDFs.
        //
        // Compute average PDF, except in the specular case: a specular BxDF has a delta
        // distribution of directions, that is, a given wo will always be mapped to a unique wi
        // with probability 1 (pdf = 1 here already).
        if (bxdfType != BRDF_SPECULAR && matchingComps > 1) {
            // TODO: revisit when we have more than 1 non-specular BxDFs.

            // Add only the pdf of non-specular BxDFs that aren't bxdfType (pdf already stores
            // the pdf of the selected bxdfType).
            pdf += specularBRDF.Pdf(wo, wi);
        }
        if (matchingComps > 1) {
            pdf /= matchingComps;
        }

        // Compute value of BSDF for sampled direction.
        if (bxdfType != BRDF_SPECULAR) {
            // TODO: revisit when we have more than 1 non-specular BxDFs.

            bool reflect = dot(wiW, ng) * dot(woW, ng) > 0;

            f = 0.0f;

            if (reflect && hasDiffuseBRDF) {
                f += diffuseBRDF.f(wo, wi);
            }
            if (reflect && hasSpecularBRDF) {
                f += specularBRDF.f(wo, wi);
            }
            if (reflect && hasAshikhminShirleyBRDF) {
                f += ashikhminShirleyBRDF.f(wo, wi);
            }
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
        if (hasAshikhminShirleyBRDF) {
            pdf += ashikhminShirleyBRDF.Pdf(wo, wi);
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

    it.bsdf.hasAshikhminShirleyBRDF = true;
    it.bsdf.ashikhminShirleyBRDF.Rd = shadingData.diffuse;
    it.bsdf.ashikhminShirleyBRDF.Rs = shadingData.specular;
    it.bsdf.ashikhminShirleyBRDF.sn = shadingData.N;
    it.bsdf.ashikhminShirleyBRDF.roughness = shadingData.roughness;
    it.bsdf.ashikhminShirleyBRDF.distribution.alphaX = it.bsdf.ashikhminShirleyBRDF.distribution.RoughnessToAlpha(shadingData.roughness);
    it.bsdf.ashikhminShirleyBRDF.distribution.alphaY = it.bsdf.ashikhminShirleyBRDF.distribution.RoughnessToAlpha(shadingData.roughness);
    // TODO: disabling these so that only AshikhminShirleyBRDF is used. 
    it.bsdf.hasDiffuseBRDF = false;
    it.bsdf.hasSpecularBRDF = false;
    it.bsdf.nBxDFs++;
}