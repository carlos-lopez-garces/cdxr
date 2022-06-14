#include "LambertianReflectionAndShadowsPass.h"

namespace {
    // Shader.
    const char *kShaderFile = "Shaders\\LambertianReflectionAndShadows.rt.hlsl";

    // Shader entrypoints;
    const char* kEntryPointRayGen = "LamberAndShadowsRayGen";
	const char* kEntryPointMiss0 = "ShadowMiss";
	const char* kEntryPointAnyHit = "ShadowAnyHit";
	const char* kEntryPointClosestHit = "ShadowClosestHit";
};

bool LambertianReflectionAndShadowsPass::initialize(Falcor::RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;
    mpResManager->requestTextureResources({
        "WorldPosition", "WorldNormal", "MaterialDiffuse"
    });
    mpResManager->requestTextureResource(ResourceManager::kOutputChannel);

    mpResManager->setDefaultSceneName("Scenes\\PinkRoom\\pink_room.fscene");

    mpRayTracer = RayLaunch::create(kShaderFile, kEntryPointRayGen);
    mpRayTracer->addMissShader(kShaderFile, kEntryPointMiss0);
    mpRayTracer->addHitShader(kShaderFile, kEntryPointClosestHit, kEntryPointAnyHit);
    mpRayTracer->compileRayProgram();
    if (mpScene) {
        mpRayTracer->setScene(mpScene);
    }

    return true;
}

void LambertianReflectionAndShadowsPass::initScene(Falcor::RenderContext* pRenderContext, Scene::SharedPtr pScene) {
    mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
	if (mpRayTracer) {
        mpRayTracer->setScene(mpScene);
    }
}