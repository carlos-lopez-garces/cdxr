#include "Falcor.h"
#include "GGXGIPass.h"
#include "../SharedUtils/ResourceManager.h"
#include "../SharedUtils/RayLaunch.h"

namespace {
    // Shader file.
    const char *kShaderFile = "Shaders\\GGXGI.rt.hlsl";

    // Entrypoints.
    const char *kEntryPointRayGen = "GGXGIRayGen";
    const char *kEntryPointGGXGIClosestHit = "GGXGIClosestHit";
    const char *kEntryPointGGXGIAnyHit = "GGXGIAnyHit";
    const char *kEntryPointGGXGIMiss = "GGXGIMiss";
    const char *kEntryPointShadowClosestHit = "ShadowClosestHit";
    const char *kEntryPointShadowAnyHit = "ShadowAnyHit";
    const char *kEntryPointShadowMiss = "ShadowMiss";
};

bool GGXGIPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;

    mpResManager->requestTextureResources({
        "WorldPosition", "WorldNormal", "MaterialDiffuse", "MaterialSpecRough", "MaterialExtraParams", "Emissive"
    });
    mpResManager->requestTextureResource(mOutputBuffer);
    mpResManager->requestTextureResource(ResourceManager::kEnvironmentMap);

    mpResManager->setDefaultSceneName("Data/pink_room/pink_room.fscene");

    mpRayTracer = RayLaunch::create(kShaderFile, kEntryPointRayGen);

    // Ray type / hit group 0: shadow rays.
    mpRayTracer->addMissShader(kShaderFile, kEntryPointShadowMiss);
    mpRayTracer->addHitShader(kShaderFile, kEntryPointShadowClosestHit, kEntryPointShadowAnyHit);

    // Ray type / hit group 1: GI rays.
    mpRayTracer->addMissShader(kShaderFile, kEntryPointGGXGIMiss);
    mpRayTracer->addHitShader(kShaderFile, kEntryPointGGXGIClosestHit, kEntryPointGGXGIAnyHit);

    mpRayTracer->compileRayProgram();
    mpRayTracer->setMaxRecursionDepth(uint32_t(mMaxRayDepth));
    if (mpScene) {
        mpRayTracer->setScene(mpScene);
    }

    return true;
}


void GGXGIPass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) {
    mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
    if (mpRayTracer) mpRayTracer->setScene(mpScene);
}

void GGXGIPass::execute(RenderContext* pRenderContext) {
    Texture::SharedPtr outputTex = mpResManager->getClearedTexture(mOutputBuffer, vec4(0.0f, 0.0f, 0.0f, 0.0f));

    if (!outputTex || !mpRayTracer || !mpRayTracer->readyToRender()) {
        return;
    }

    auto globalVars = mpRayTracer->getGlobalVars();
    globalVars["GlobalCB"]["gFrameCount"] = mFrameCount++;
    globalVars["GlobalCB"]["gMinT"] = mpResManager->getMinTDist();
    globalVars["RayGenCB"]["gTMax"] = FLT_MAX;
    globalVars["RayGenCB"]["gMaxDepth"] = mRayDepth;
    globalVars["RayGenCB"]["gDoDirectGI"] = mDoDirectGI;
    globalVars["RayGenCB"]["gDoIndirectGI"] = mDoIndirectGI;
    globalVars["RayGenCB"]["gEmitMult"] = 1.0f;
    globalVars["gPos"] = mpResManager->getTexture("WorldPosition");
	globalVars["gNorm"] = mpResManager->getTexture("WorldNormal");
	globalVars["gDiffuseMatl"] = mpResManager->getTexture("MaterialDiffuse");
	globalVars["gSpecMatl"] = mpResManager->getTexture("MaterialSpecRough");
	globalVars["gExtraMatl"] = mpResManager->getTexture("MaterialExtraParams");
    globalVars["gEmissive"] = mpResManager->getTexture("Emissive");
    globalVars["gEnvMap"] = mpResManager->getTexture(ResourceManager::kEnvironmentMap);
	globalVars["gOutput"] = outputTex;

    mpRayTracer->execute(pRenderContext, mpResManager->getScreenSize());
}

void GGXGIPass::renderGui(Gui* pGui) {
    int dirty = 0;

    dirty |= (int)pGui->addIntVar("Max RayDepth", mRayDepth, 0, mMaxRayDepth);

	dirty |= (int)pGui->addCheckBox(mDoDirectGI ? "Do direct illumination" : "Don't do direct illumination", mDoDirectGI);

	dirty |= (int)pGui->addCheckBox(mDoIndirectGI ? "Do indirect illumination" : "Don't do indirect illumination", mDoIndirectGI);

	if (dirty) {
        setRefreshFlag();
    }
}