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
	mpRayTracer = RayLaunch::create(kFileRayTrace, kEntryPointRayGen);
	mpRayTracer->addHitShader(kFileRayTrace, "", kEntryPointAnyHit);
	mpRayTracer->addMissShader(kFileRayTrace, kEntryPointMiss0);
	mpRayTracer->compileRayProgram();

	if (mpScene) {
		mpRayTracer->setScene(mpScene);
	}

	return true;
}

void RayTracedAmbientOcclusionPass::initScene(RenderContext *pRenderContext, Falcor::Scene::SharedPtr pScene) {
	// std::dynamic_pointer_cast creates a new std::shared_ptr from pScene's stored pointer
	// after downcasting it (RtScene is a derived class of Scene).
	mpScene = std::dynamic_pointer_cast<RtScene>(pScene);

	if (mpRayTracer) {
		mpRayTracer->setScene(mpScene);
	}

	if (!mpScene) {
		return;
	}

	// By default, the AO radius is 5% the size of the scene's radius.
	mAoRadius = glm::max(0.1f, mpScene->getRadius() * 0.05f);
}

void RayTracedAmbientOcclusionPass::execute(RenderContext *pRenderContext) {
	Falcor::Texture::SharedPtr pOutputTex = mpResManager->getClearedTexture(
		ResourceManager::kOutputChannel,
		vec4(0.0f, 0.0f, 0.0f, 0.0f)
	);

	if (!pOutputTex || !mpRayTracer || !mpRayTracer->readyToRender()) {
		return;
	}

	// Set raygeneration shader variables. No variables are set for the other
	// types of shaders.
	auto rayGenVars = mpRayTracer->getRayGenVars();
	rayGenVars["RayGenCB"]["gFrameCount"] = mFrameCount++;
	rayGenVars["RayGenCB"]["gAoRadius"] = mAoRadius;
	// Retrived from the UI.
	rayGenVars["RayGenCB"]["gMinT"] = mpResManager->getMinTDist();
	rayGenVars["RayGenCB"]["gNumRays"] = mNumRaysPerPixel;
	// G-Buffer.
	rayGenVars["gPos"] = mpResManager->getTexture("WorldPosition");
	rayGenVars["gNorm"] = mpResManager->getTexture("WorldNormal");
	rayGenVars["gOutput"] = pOutputTex;

	mpRayTracer->execute(pRenderContext, mpResManager->getScreenSize());
}