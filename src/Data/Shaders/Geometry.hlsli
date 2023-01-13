// Obtains an orthonormal basis out of v1. Assumes that v1 is normalized.
void CoordinateSystem(
    float3 v1, inout float3 v2, inout float3 v3
) {
    if (abs(v1.x) > abs(v1.y)) {
        v2 = float3(-v1.z, 0, v1.x) / sqrt(v1.x*v1.x + v1.z*v1.z);
    } else {
        v2 = float3(0, v1.z, -v1.y) / sqrt(v1.y*v1.y + v1.z*v1.z);
    }

    v3 = cross(v1, v2);
}

struct Interaction {
	float2 pixelIndex;
	float3 p;
	float3 n;
	float3 shadingNormal;
	float3 wo;
	float3 wi;
	float pdf;
	BSDF bsdf;
	bool isSurfaceInteraction;

	bool IsSurfaceInteraction() {
		return isSurfaceInteraction;
	}
};

struct SurfaceInteraction {
	// TODO: optimize packing.
	float3 p;
	float3 n;
	float3 shadingNormal;
	float4 color;
	float16_t2 uvs;
	float3 emissive;
	float3 brdf;
	float brdfType;
	float brdfProbability;
	float pdf;
	float3 wi;
	float3 wo;
	float3 directL;
	float3 Le;

	bool hit;

	bool IsSurfaceInteraction() {
		return true;
	}

	bool hasHit() {
		return hit;
	}
};

float2 octWrap(float2 v) {
	return float2((1.0f - abs(v.y)) * (v.x >= 0.0f ? 1.0f : -1.0f), (1.0f - abs(v.x)) * (v.y >= 0.0f ? 1.0f : -1.0f));
}

float3 decodeNormalOctahedron(float2 p) {
	float3 n = float3(p.x, p.y, 1.0f - abs(p.x) - abs(p.y));
	float2 tmp = (n.z < 0.0f) ? octWrap(float2(n.x, n.y)) : float2(n.x, n.y);
	n.x = tmp.x;
	n.y = tmp.y;
	return normalize(n);
}

void decodeNormals(float4 encodedNormals, out float3 geometryNormal, out float3 shadingNormal) {
	geometryNormal = decodeNormalOctahedron(encodedNormals.xy);
	shadingNormal = decodeNormalOctahedron(encodedNormals.zw);
}

float3 Dot(float3 u, float3 v) {
	return u.x*v.x + u.y*v.y + u.z*v.z;
}

float3 AbsDot(float3 u, float3 v) {
	return abs(Dot(u, v));
}

// Flip u so that it lies in the same hemisphere as v.
float3 FaceForward(float3 u, float3 v) {
	return (dot(u, v) < 0.f) ? -u : u;
}

// Converts a spherical coordinate to a rectangular coordinate in a standard coordinate system.
// Theta is measured from the z axis. Phi is measured about the z axis from the x axis.
float3 SphericalDirection(float sinTheta, float cosTheta, float phi) {
    return float3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
}