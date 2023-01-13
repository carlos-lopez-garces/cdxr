float pow5(float v) {
    return (v*v) * (v*v) * v;
};

struct AshikhminShirleyBRDF {
    // Diffuse reflectance.
    float3 Rd;

    // Glossy specular reflectance.
    float3 Rs;

    // Shading normal.
    float3 sn;

    float roughness;

    // Microfacet distribution for the glossy coat.
    TrowbridgeReitzDistribution distribution;

    // Evaluates Schlick's approximation to the Fresnel equations.
    float3 SchlickFresnel(float cosTheta) {
        return Rs + pow5(1 - cosTheta) * (float3(1.f, 1.f, 1.f) - Rs);
    }

    // Evaluates the Ashikhmin-Shirley BRDF for the input pair of incident and reflected
    // directions. 
    float3 f(float3 wo, float3 wi) {
        // The specular microfacet distribution is a function of the half vector.
        float3 wh = wi + wo;
        if (wh.x == 0 && wh.y == 0 && wh.z == 0) {
            return float3(0.f);
        }
        wh = normalize(wh);

        float3 specularTerm = distribution.D(wh)
            * SchlickFresnel(dot(wi, wh))
            / (4 * abs(dot(wi, wh)) * max(AbsCosTheta(wi), AbsCosTheta(wo)));

        float3 diffuseTerm = (28.f / (23.f * M_PI))
            * Rd
            * (float3(1.f) - Rs)
            * (1 - pow5(1 - 0.5f * AbsCosTheta(wi))) 
            * (1 - pow5(1 - 0.5f * AbsCosTheta(wo)));

        return diffuseTerm + specularTerm;
    }

    // Samples the Ashikhmin-Shirley BRDF.
    float3 Sample_f(
        float3 wo,
        inout float3 wi,
        float2 u,
        inout float pdf
    ) {
        float2 uRemapped = u;
        if (u.x < 0.5) {
            // Sample the diffuse term.

            // The uniform random sample u = (u_0, u_1) is used by CosineSampleHemisphere,
            // but u_0 < 0.5 at this point because it was used to select the diffuse term
            // (this conditional branch). Remap u_0 to the range [0,1).
            uRemapped.x = min(2*u.x, ONE_MINUS_EPSILON);

            // Diffuse reflection.
            wi = CosineSampleHemisphere(uRemapped);
            if (wo.z < 0.0) {
                // CosineSampleHemisphere sampled wi on an arbitrary hemisphere of 
                // reflection space. Invert wi so that it lies on the same
                // hemisphere as wo.
                wi.z *= -1;
            }
        } else {
            // Sample the glossy specular term.

            // The uniform random sample u = (u_0, u_1) is used by distribution->Sample_wh,
            // but u_0 >= 0.5 at this point because it was used to select the specular term
            // (this conditional branch). Remap u_0 to the range [0,1).
            uRemapped.x = min(2 * (u.x - 0.5f), ONE_MINUS_EPSILON);

            float3 wh = distribution.Sample_wh(wo, uRemapped);
            wi = Reflect(wo, wh);
            if (!SameHemisphere(wo, wi)) {
                return float3(0.f);
            }
        }

        pdf = Pdf(wo, wi);

        return f(wo, wi);
    }

    // Obtains the probability of sampling wi given wo.
    float Pdf(float3 wo, float3 wi) {
        if (!SameHemisphere(wo, wi)) {
            return 0.f;
        }

        // Half vector.
        float3 wh = normalize(wo + wi);

        float diffusePdf = AbsCosTheta(wi) * M_1_PI;
        float specularPdf = distribution.Pdf(wo, wh) / (4 * dot(wo, wh));

        // Average.
        return 0.5f * (diffusePdf + specularPdf);
    }

};