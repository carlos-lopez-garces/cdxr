struct Interaction {
	float3 p;
	float3 n;
	float3 shadingNormal;
	float3 wo;
	float3 wi;
	float pdf;
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

	void ComputeScatteringFunctions(RayDesc ray) {
		// TODO: Compute differentials of P and UV mappings. They may be needed next by materials
    	// that evaluate textures to obtain BSDF parameters.
		if (IsBlack(brdf)) {
			return;
		}
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