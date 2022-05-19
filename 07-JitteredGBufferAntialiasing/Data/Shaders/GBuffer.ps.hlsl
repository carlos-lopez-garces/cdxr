__import Shading;
__import DefaultVS;

struct GBuffer {
    float4 wsPos    : SV_Target0;
	float4 wsNorm   : SV_Target1;
	float4 matDif   : SV_Target2;
	float4 matSpec  : SV_Target3;
	float4 matExtra : SV_Target4;
};

GBuffer main(VertexOut vsOut, uint primID : SV_PrimitiveID, float4 pos : SV_POSITION) {
	ShadingData hitPt = prepareShadingData(vsOut, gMaterial, gCamera.posW);

	float NdotV = dot(normalize(hitPt.N.xyz), normalize(gCamera.posW - hitPt.posW));
	if (NdotV <= 0.0f && hitPt.doubleSidedMaterial) {
		hitPt.N = -hitPt.N;
	}

	GBuffer gBufOut;
	// From frame to frame and for a given pixel, wsPos varies randomly when random
	// camera jittering is added, because rasterization may sample a different fragment.
	gBufOut.wsPos = float4(hitPt.posW, 1.f);
	gBufOut.wsNorm = float4(hitPt.N, length(hitPt.posW - gCamera.posW) );
	gBufOut.matDif = float4(hitPt.diffuse, hitPt.opacity);
	gBufOut.matSpec = float4(hitPt.specular, hitPt.linearRoughness);
	gBufOut.matExtra = float4(hitPt.IoR, hitPt.doubleSidedMaterial ? 1.f : 0.f, 0.f, 0.f);

    return gBufOut;
}