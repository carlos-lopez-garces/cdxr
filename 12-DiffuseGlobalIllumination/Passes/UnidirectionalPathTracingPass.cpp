#include "Falcor.h"
#include "UnidirectionalPathTracingPass.h"
#include "../SharedUtils/ResourceManager.h"
#include "../SharedUtils/RayLaunch.h"

namespace {
    // Shader file.
    const char *kShaderFile = "Shaders\\PathTracing.rt.hlsl";

    // Entrypoints.
    const char *kEntryPointRayGen = "PathTracingRayGen";
    const char *kEntryPointGIClosestHit = "GIClosestHit";
    const char *kEntryPointGIAnyHit = "GIAnyHit";
    const char *kEntryPointGIMiss = "GIMiss";
    const char *kEntryPointShadowClosestHit = "ShadowClosestHit";
    const char *kEntryPointShadowAnyHit = "ShadowAnyHit";
    const char *kEntryPointShadowMiss = "ShadowMiss";
};

bool UnidirectionalPathTracingPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;

    mpResManager->requestTextureResources({
        "WorldPosition", "WorldNormal", "WorldShadingNormal", "MaterialDiffuse", "MaterialEmissive"
    });
    mpResManager->requestTextureResource(mOutputBuffer);
    mpResManager->requestTextureResource(ResourceManager::kEnvironmentMap);

    mpResManager->setDefaultSceneName("Data/pink_room/pink_room.fscene");

    mpRayTracer = RayLaunch::create(kShaderFile, kEntryPointRayGen);

    // Ray type / hit group 0: shadow rays.
    mpRayTracer->addHitShader(kShaderFile, kEntryPointShadowClosestHit, kEntryPointShadowAnyHit);
    mpRayTracer->addMissShader(kShaderFile, kEntryPointShadowMiss);

    // Ray type / hit group 1: GI rays.
    mpRayTracer->addHitShader(kShaderFile, kEntryPointGIClosestHit, kEntryPointGIAnyHit);
    mpRayTracer->addMissShader(kShaderFile, kEntryPointGIMiss);


    mpRayTracer->compileRayProgram();
    if (mpScene) {
        mpRayTracer->setScene(mpScene);
    }

    return true;
}


void UnidirectionalPathTracingPass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) {
    mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
    if (mpRayTracer) mpRayTracer->setScene(mpScene);
}

void UnidirectionalPathTracingPass::execute(RenderContext* pRenderContext) {
    Texture::SharedPtr outputTex = mpResManager->getClearedTexture(mOutputBuffer, vec4(0.0f, 0.0f, 0.0f, 0.0f));

    if (!outputTex || !mpRayTracer || !mpRayTracer->readyToRender()) {
        return;
    }

    auto rayGenVars = mpRayTracer->getRayGenVars();
    rayGenVars["RayGenCB"]["gFrameCount"] = mFrameCount++;
    rayGenVars["RayGenCB"]["gMaxBounces"] = mMaxBounces;
    rayGenVars["RayGenCB"]["gMinBouncesBeforeRussianRoulette"] = mMinBouncesBeforeRussianRoulette;
    rayGenVars["RayGenCB"]["gTMin"] = mpResManager->getMinTDist();
    rayGenVars["RayGenCB"]["gTMax"] = FLT_MAX;
    rayGenVars["RayGenCB"]["gDoCosineSampling"] = mDoCosSampling;
    rayGenVars["gWsPos"] = mpResManager->getTexture("WorldPosition");     
	rayGenVars["gWsNorm"] = mpResManager->getTexture("WorldNormal");
    rayGenVars["gWsShadingNorm"] = mpResManager->getTexture("WorldShadingNormal");
	rayGenVars["gMatDif"] = mpResManager->getTexture("MaterialDiffuse");
    rayGenVars["gMatEmissive"] = mpResManager->getTexture("MaterialEmissive");
	rayGenVars["gOutput"] = outputTex;

    // TODO: should be 1 instead of 0, because it is hitgroup 1 that uses gEnvMap; but if set to 1,
    // the render doesn't converge and there are very bright pixels.
    auto giMissVars = mpRayTracer->getMissVars(0);
    // Color sampled by all rays that escape the scene without hitting anything. Constant buffer.
    giMissVars["gEnvMap"] = mpResManager->getTexture(ResourceManager::kEnvironmentMap);

    mpRayTracer->execute(pRenderContext, mpResManager->getScreenSize());
}

void UnidirectionalPathTracingPass::renderGui(Gui* pGui) {
    int dirty = 0;

    dirty |= (int)pGui->addCheckBox(mDoCosSampling ? "Cosine-weighted hemisphere sampling" : "Uniform hemisphere sampling", mDoCosSampling);

	if (dirty) {
        setRefreshFlag();
    }
}