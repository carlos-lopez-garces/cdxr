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

// Uniform sampling of the hemisphere of directions.
float3 getUniformHemisphereSample(inout uint seed, float3 hitNormal) {
	float2 randVal = float2(nextRand(seed), nextRand(seed));

	float3 bitangent = getPerpendicularVector(hitNormal);
	float3 tangent = cross(bitangent, hitNormal);
	float r = sqrt(max(0.0f,1.0f - randVal.x*randVal.x));
	float phi = 2.0f * 3.14159265f * randVal.y;

	return tangent * (r * cos(phi).x) + bitangent * (r * sin(phi)) + hitNormal.xyz * randVal.x;
}

// Convert world space direction to a (u,v) coordindate in a latitude-longitude spherical map.
float2 WorldToLatitudeLongitude(float3 dir) {
	float3 p = normalize(dir);
	float u = (1.f + atan2(p.x, -p.z) * M_1_PI) * 0.5f;
	float v = acos(p.y) * M_1_PI;
	return float2(u, v);
}

// Offsets a ray origin from current position p, along normal n (which must be geometric normal)
// so that no self-intersection can occur. See Ray Tracing Gems Ch. 6: A Fast and Robust Method
// for Avoiding Self-Intersection.
float3 offsetRayOrigin(const float3 p, const float3 n) {
	// Don't declare 'static' variables. The keyword causes slang run-time failures.
	const float origin = 1.0f / 32.0f;
	const float float_scale = 1.0f / 65536.0f;
	const float int_scale = 256.0f;

	int3 of_i = int3(int_scale * n.x, int_scale * n.y, int_scale * n.z);

	float3 p_i = float3(
		asfloat(asint(p.x) + ((p.x < 0) ? -of_i.x : of_i.x)),
		asfloat(asint(p.y) + ((p.y < 0) ? -of_i.y : of_i.y)),
		asfloat(asint(p.z) + ((p.z < 0) ? -of_i.z : of_i.z))
	);

	return float3(
		abs(p.x) < origin ? p.x + float_scale * n.x : p_i.x,
		abs(p.y) < origin ? p.y + float_scale * n.y : p_i.y,
		abs(p.z) < origin ? p.z + float_scale * n.z : p_i.z
	);
}