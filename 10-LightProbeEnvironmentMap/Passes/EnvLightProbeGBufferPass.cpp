#include "EnvLightProbeGBufferPass.h"

namespace {
    // Shader.
    const char *kShaderFile = "Shaders\\EnvLightProbeGBuffer.rt.hlsl";

    // Shader entrypoints;
    const char* kEntryPointRayGen = "EnvLightProbeRayGen";
	const char* kEntryPointMiss0 = "EnvLightProbeMiss";
	const char* kEntryPointAnyHit = "EnvLightProbeAnyHit";
	const char* kEntryPointClosestHit = "EnvLightProbeClosestHit";

    // Environment map file.
    const char* kEnvironmentMap = "Textures\\MonValley_G_DirtRoad_3k.hdr";
};

bool EnvLightProbeGBufferPass::initialize(Falcor::RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;
    mpResManager->requestTextureResources({
        "WorldPosition", "WorldNormal", "MaterialDiffuse"
    });
    mpResManager->requestTextureResource(ResourceManager::kOutputChannel);

    mpResManager->updateEnvironmentMap(kEnvironmentMap);

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

void EnvLightProbeGBufferPass::execute(Falcor::RenderContext* pRenderContext) {
    if (!mpRayTracer || !mpRayTracer->readyToRender()) {
        return;
    }

    auto rayGenVars = mpRayTracer->getRayGenVars();
    rayGenVars["gPos"] = mpResManager->getTexture("WorldPosition");     
    rayGenVars["gNorm"] = mpResManager->getTexture("WorldNormal");

    auto missVars = mpRayTracer->getMissVars(0);
    missVars["gEnvMap"] = mpResManager->getTexture(ResourceManager::kEnvironmentMap);
    missVars["gMatDif"] = mpResManager->getTexture("MaterialDiffuse");

    mpRayTracer->execute(pRenderContext, mpResManager->getScreenSize());
}

void EnvLightProbeGBufferPass::initScene(Falcor::RenderContext* pRenderContext, Scene::SharedPtr pScene) {
    mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
    if (mpRayTracer) {
        mpRayTracer->setScene(mpScene);
    }
}
