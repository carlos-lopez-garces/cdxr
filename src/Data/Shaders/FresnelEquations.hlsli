// A Fresnel interface that reflects all the incident light in its entirety: no absorption,
// no transmission.
float3 evaluateNoOpFresnel(float cosThetaI) {
    return float3(1.f, 1.f, 1.f);
}