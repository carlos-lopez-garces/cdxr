// A Fresnel interface that reflects all the incident light in its entirety: no absorption,
// no transmission.
float3 evaluateNoOpFresnel(float cosThetaI) {
    return float3(1.f, 1.f, 1.f);
}

// From github.com/boksajak/referencePT.
float3 evaluateSchlickFresnel(float3 f0, float f90, float NdotS) {
	return f0 + (float3(f90, f90, f90) - f0) * pow(1.0f - NdotS, 5.0f);
}

// From github.com/boksajak/referencePT.
float3 evaluateFresnel(float3 f0, float f90, float NdotS) {
	return evaluateSchlickFresnel(f0, f90, NdotS);
}