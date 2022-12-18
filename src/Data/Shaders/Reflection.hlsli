bool SameHemisphere(float3 u, float3 v) {
    return (u.z * v.z) > 0;
}

float AbsCosTheta(float3 w) {
    return abs(w.z);
}