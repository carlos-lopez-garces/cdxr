// The shading coordinate system is defined by the orthonormal basis {s, t, n} = {x, y, z},
// where s and t are 2 orthogonal vectors tangent to the shaded point and n is the normal
// of the surface at this point.
//
// This coordinate system defines the spherical coordinates of a vector w as (theta, phi),
// where theta is measured from the z axis and phi is measured about the z axis and from the
// x axis to the projection of w onto the xy plane (the length of the projection is sin(theta)).
//
// Vector w is expected to be expressed as a linear combination of {s, t, n}, normalized, and
// outward facing (even if it is an incident direction). When it is an incident direction, it
// will always be in the same hemisphere as the normal n. 

float CosTheta(float3 w) {
    return w.z;
}

float AbsCosTheta(float3 w) {
    return abs(w.z);
}

bool SameHemisphere(float3 u, float3 v) {
    return (u.z * v.z) > 0;
}

// Specifies minimal reflectance for dielectrics (when metalness is zero).
// See https://github.com/boksajak/referencePT/blob/eb4eb0e66474bf90e72b9d86b3537ca1a8cdb469/shaders/brdf.h#L102.
#define MIN_DIELECTRICS_F0 0.04f

// From github.com/boksajak/referencePT.
float3 baseColorToSpecularF0(float3 baseColor, float metalness) {
	return lerp(float3(MIN_DIELECTRICS_F0, MIN_DIELECTRICS_F0, MIN_DIELECTRICS_F0), baseColor, metalness);
}

// From github.com/boksajak/referencePT.
float3 baseColorToDiffuseReflectance(float3 baseColor, float metalness) {
	return baseColor * (1.0f - metalness);
}

// From github.com/boksajak/referencePT.
float shadowedF90(float3 F0) {
	const float t = (1.0f / MIN_DIELECTRICS_F0);
	return min(1.0f, t * luminance(F0));
}