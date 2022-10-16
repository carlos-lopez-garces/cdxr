#define BXDF_DIFFUSE 1
#define BXDF_SPECULAR 2

struct BxDF {
    float3 Sample_f(
        float3 wo,
        inout float3 wi,
        float2 sample,
        inout float pdf,
        inout int sampledType
    ) {
        return float3(0.0f, 0.0f, 0.0f);
    }
};