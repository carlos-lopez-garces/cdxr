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