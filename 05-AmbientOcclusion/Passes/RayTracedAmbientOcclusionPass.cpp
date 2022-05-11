#include "RayTracedAmbientOcclusionPass.h"

namespace {
	// Ray tracing shader file.
	const char *kFileRayTrace = "Shaders\\AoTracing.rt.hlsl";

	// Raygeneration, miss (for hit group #0), and anyhit shader entrypoints. Note
	// that there's no closesthit shader.
	const char *kEntryPointRayGen = "AoRayGen";
	const char *kEntryPointMiss0 = "AoMiss";
	const char *kEntryPointAnyHit = "AoAnyHit";
};

bool RayTracedAmbientOcclusionPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
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

void RayTracedAmbientOcclusionPass::initScene(RenderContext *pRenderContext, Falcor::Scene::SharedPtr pScene) {
	// std::dynamic_pointer_cast creates a new std::shared_ptr from pScene's stored pointer
	// after downcasting it (RtScene is a derived class of Scene).
	mpScene = std::dynamic_pointer_cast<RtScene>(pScene);

	if (mpRays) {
		mpRays->setScene(mpScene);
	}

	if (!mpScene) {
		return;
	}

	// By default, the AO radius is 5% the size of the scene's radius.
	mAoRadius = glm::max(0.1f, mpScene->getRadius() * 0.05f);
}