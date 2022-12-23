#include "Falcor.h"
#include "UnidirectionalPathTracingPass.h"
#include "../SharedUtils/ResourceManager.h"
#include "../SharedUtils/RayLaunch.h"

namespace {
    // Shader file.
    const char *kShaderFile = "Shaders\\PathTracing.rt.hlsl";

    // Entrypoints.
    const char *kEntryPointRayGen = "PathTracingRayGen";
    const char *kEntryPointPTClosestHit = "PTClosestHit";
    const char *kEntryPointPTAnyHit = "PTAnyHit";
    const char *kEntryPointPTMiss = "PTMiss";

    // Environment map file.
    const char* kEnvironmentMap = "MonValley_G_DirtRoad_3k.hdr";
};

bool UnidirectionalPathTracingPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;

    mpResManager->requestTextureResources({
        "PrimaryRayOriginOnLens",
        "PrimaryRayDirection",
        "WorldPosition",
        "WorldNormal",
        "WorldShadingNormal",
        "DiffuseColor",
        "DirectL"
    });
    mpResManager->requestTextureResource(mOutputBuffer);
    mpResManager->updateEnvironmentMap(kEnvironmentMap);
    mpResManager->setDefaultSceneName("Data/pink_room/pink_room.fscene");

    mpRayTracer = RayLaunch::create(kShaderFile, kEntryPointRayGen);
    // Ray type / hit group 0: path tracing rays.
    mpRayTracer->addMissShader(kShaderFile, kEntryPointPTMiss);
    mpRayTracer->addHitShader(kShaderFile, kEntryPointPTClosestHit, kEntryPointPTAnyHit);

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
    Texture::SharedPtr diffuseColorTex = mpResManager->getClearedTexture("DiffuseColor", vec4(0.0f, 0.0f, 0.0f, 0.0f));
    Texture::SharedPtr directLTex = mpResManager->getClearedTexture("DirectL", vec4(0.0f, 0.0f, 0.0f, 0.0f));
    Texture::SharedPtr leTex = mpResManager->getClearedTexture("Le", vec4(0.0f, 0.0f, 0.0f, 0.0f));
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
    rayGenVars["gWsPos"] = mpResManager->getTexture("WorldPosition");     
	rayGenVars["gWsNorm"] = mpResManager->getTexture("WorldNormal");
    rayGenVars["gWsShadingNorm"] = mpResManager->getTexture("WorldShadingNormal");
    rayGenVars["gRayOriginOnLens"] = mpResManager->getTexture("PrimaryRayOriginOnLens");
    rayGenVars["gPrimaryRayDirection"] = mpResManager->getTexture("PrimaryRayDirection");
    rayGenVars["gDiffuseColor"] = diffuseColorTex;
    rayGenVars["gDirectL"] = directLTex;
    rayGenVars["gLe"] = leTex;
	rayGenVars["gOutput"] = outputTex;

    // Set up variables for all hit shaders of the PT shader.
    for (auto ptHitVars : mpRayTracer->getHitVars(0)) {
        ptHitVars["gDiffuseColor"] = diffuseColorTex;
        ptHitVars["gDirectL"] = directLTex;
        ptHitVars["gLe"] = leTex;
    }

    // TODO: should be 1 instead of 0, because it is hitgroup 1 that uses gEnvMap; but if set to 1,
    // the render doesn't converge and there are very bright pixels.
    auto ptMissVars = mpRayTracer->getMissVars(0);
    // Color sampled by all rays that escape the scene without hitting anything. Constant buffer.
    ptMissVars["gEnvMap"] = mpResManager->getTexture(ResourceManager::kEnvironmentMap);
    ptMissVars["gDirectL"] = directLTex;

    mpRayTracer->execute(pRenderContext, mpResManager->getScreenSize());
}