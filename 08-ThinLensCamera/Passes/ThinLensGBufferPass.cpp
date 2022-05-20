#include <chrono>
#include "ThinLensGBufferPass.h"

namespace {
    // Shader.
    const char *kFileRayTrace = "Shaders\\ThinLensGBuffer.rt.hlsl";

    // Shader entrypoints;
    const char* kEntryPointRayGen = "GBufferRayGen";
	const char* kEntryPointMiss0 = "PrimaryMiss";
	const char* kEntryPrimaryAnyHit = "PrimaryAnyHit";
	const char* kEntryPrimaryClosestHit = "PrimaryClosestHit";
};

bool ThinLensGBufferPass::initialize(Falcor::RenderContext *pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;

    // Request G-Buffer textures.
    mpResManager->requestTextureResources({
        // Channels.
        "WorldPosition", "WorldNormal", "MaterialDiffuse", "MaterialSpecRough", "MaterialExtraParams"
    });

    mpResManager->setDefaultSceneName("Scenes\\PinkRoom\\pink_room.fscene");

    // Set up the ray tracer.
    mpRayTracer = RayLaunch::create(kFileRayTrace, kEntryPointRayGen);
    mpRayTracer->addMissShader(kFileRayTrace, kEntryPointMiss0);
    mpRayTracer->addHitShader(kFileRayTrace, kEntryPrimaryClosestHit, kEntryPrimaryAnyHit);
    mpRayTracer->compileRayProgram();
    if (mpScene) {
        mpRayTracer->setScene(mpScene);
    }

    // Set up the pseudo-random number generator.
    auto currentTime = std::chrono::high_resolution_clock::now();
    auto timeInMilliSecs = std::chrono::time_point_cast<std::chrono::milliseconds>(currentTime);
    mPRNG = std::mt19937(uint32_t(timeInMilliSecs.time_since_epoch().count()));

    // A larger GUI?
    setGuiSize(ivec2(250, 300));
    return true;
}