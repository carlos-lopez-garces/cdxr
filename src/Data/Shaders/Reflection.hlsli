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

float SinTheta(float3 w) {
    return sqrt(Sin2Theta(w));
}

float Sin2Theta(float3 w) {
    // Pythagorean identity.
    return max((float) 0, (float) 1 - Cos2Theta(w));
}

// Computes the cosine of theta, the angle between the normal in shading space and
// and w. In shading space, n = (0,0,1) and w is normalized, so 
// cos(theta) = dot(n, w) = (0,0,1) dot (w.x, w.y, w.z) = w.z.
float CosTheta(float3 w) {
    return w.z;
}

float Cos2Theta(float3 w) {
    return w.z * w.z;
}

float AbsCosTheta(float3 w) {
    return abs(w.z);
}

float TanTheta(float3 w) {
    // Trigonometric identity.
    return SinTheta(w) / CosTheta(w);
}

float Tan2Theta(float3 w) {
    // Trigonometric identity.
    return Sin2Theta(w) / Cos2Theta(w);
}

float SinPhi(float3 w) {
    // The length of the projection of w onto the xy plane where phi is measured is given
    // by sin(theta).
    float sinTheta = SinTheta(w);

    // Trigonometric identity (the projection of w is the hypotenuse of the triangle).
    return (sinTheta == 0) ? 0 : clamp(w.y / sinTheta, -1, 1);
}

float Sin2Phi(float3 w) {
    return SinPhi(w) * SinPhi(w);
}

float CosPhi(float3 w) {
    // The length of the projection of w onto the xy plane where phi is measured is given
    // by sin(theta).
    float sinTheta = SinTheta(w);

    // Trigonometric identity (the projection of w is the hypotenuse of the triangle).
    return (sinTheta == 0) ? 1 : clamp(w.x / sinTheta, -1, 1);
}

float Cos2Phi(float3 w) {
    return CosPhi(w) * CosPhi(w);
}

bool SameHemisphere(float3 u, float3 v) {
    return (u.z * v.z) > 0;
}

float3 Reflect(float3 wo, float3 n) {
    return -wo + 2*dot(wo, n)* n;
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