#include "AmbientOcclusionPass.h"

namespace {
	// Ray tracing shader file.
	const char *kFileRayTrace = "Shaders\\AoTracing.rt.hlsl";

	// Raygeneration, miss (for hit group #0), and anyhit shader entrypoints. Note
	// that there's no closesthit shader.
	const char *kEntryPointRayGen = "AoRayGen";
	const char *kEntryPointMiss0 = "AoMiss";
	const char *kEntryPointAnyHit = "AoAnyHit";
};

bool AmbientOcclusionPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
	mpResManager = pResManager;
	mpResManager->requestTextureResources({
		"WorldPosition",
		"WorldNormal",
		ResourceManager::kOutputChannel
	});

	mpResManager->setDefaultSceneName("Data/pink_room/pink_room.fscene");

	// Set filepath to shader file and shader entrypoints.
	mpRays = RayLaunch::create(kFileRayTrace, kEntryPointRayGen);
	mpRays->addHitShader(kFileRayTrace, "", kEntryPointAnyHit);
	mpRays->addMissShader(kFileRayTrace, kEntryPointMiss0);
	mpRays->compileRayProgram();

	if (mpScene) {
		mpRays->setScene(mpScene);
	}

	return true;
}