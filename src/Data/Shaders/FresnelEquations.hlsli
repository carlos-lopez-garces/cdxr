// A Fresnel interface that reflects all the incident light in its entirety: no absorption,
// no transmission.
struct FresnelNoOp {
    float3 Evaluate(float cosThetaI) {
        return float3(1.f, 1.f, 1.f);
    }
};