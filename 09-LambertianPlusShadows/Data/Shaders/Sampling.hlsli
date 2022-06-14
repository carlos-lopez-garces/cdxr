#include "PRNG.hlsli"

// Stark's improvement to the Hughes-Moller approach to perpendicular vector generation.
// See  blog.selfshadow.com/2011/10/17/perp-vectors.
float3 getPerpendicularVector(float3 u) {
	float3 a = abs(u);
	uint xm = ((a.x - a.y) < 0 && (a.x - a.z) < 0) ? 1 : 0;
	uint ym = (a.y - a.z) < 0 ? (1 ^ xm) : 0;
	uint zm = 1 ^ (xm | ym);
	return cross(u, float3(xm, ym, zm));
}

// Cosine-weighted sampling of the hemisphere of directions.
float3 getCosHemisphereSample(inout uint seed, float3 hitNormal) {
    // Form a basis for tangent space with origin at the hit point.
    float3 bitangent = getPerpendicularVector(hitNormal);
    float3 tangent = cross(bitangent, hitNormal);

    float2 randVal = float2(nextRand(seed), nextRand(seed));
    // The first random sample corresponds to the square of the hemisphere's radius.
    float r = sqrt(randVal.x);
    // Spherical colatitude angle: a random angle between 0 and 2Pi.
    float phi = 2.0f * 3.14159265f * randVal.y;

    // The cosine-weighted sample direction is a linear combination of the tangent space
    // basis vectors.
    return (r*cos(phi))*tangent + (r*sin(phi))*bitangent + sqrt(1-randVal.x)*hitNormal;
}