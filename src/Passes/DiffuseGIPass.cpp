#include "Falcor.h"
#include "DiffuseGIPass.h"
#include "../SharedUtils/ResourceManager.h"
#include "../SharedUtils/RayLaunch.h"

namespace {
    // Shader file.
    const char *kShaderFile = "Shaders\\DiffuseGI.rt.hlsl";

    // Entrypoints.
    const char *kEntryPointRayGen = "DiffuseGIRayGen";
    const char *kEntryPointGIClosestHit = "GIClosestHit";
    const char *kEntryPointGIAnyHit = "GIAnyHit";
    const char *kEntryPointGIMiss = "GIMiss";
    const char *kEntryPointShadowClosestHit = "ShadowClosestHit";
    const char *kEntryPointShadowAnyHit = "ShadowAnyHit";
    const char *kEntryPointShadowMiss = "ShadowMiss";
};

bool DiffuseGIPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;

    mpResManager->requestTextureResources({
        "WorldPosition", "WorldNormal", "MaterialDiffuse"
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


void DiffuseGIPass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) {
    mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
    if (mpRayTracer) mpRayTracer->setScene(mpScene);
}

void DiffuseGIPass::execute(RenderContext* pRenderContext) {
    Texture::SharedPtr outputTex = mpResManager->getClearedTexture(mOutputBuffer, vec4(0.0f, 0.0f, 0.0f, 0.0f));

    if (!outputTex || !mpRayTracer || !mpRayTracer->readyToRender()) {
        return;
    }

    auto rayGenVars = mpRayTracer->getRayGenVars();
    rayGenVars["RayGenCB"]["gFrameCount"] = mFrameCount++;
    rayGenVars["RayGenCB"]["gTMin"] = mpResManager->getMinTDist();
    rayGenVars["RayGenCB"]["gTMax"] = FLT_MAX;
    rayGenVars["RayGenCB"]["gDoDirectShadows"] = mDoDirectShadows;
    rayGenVars["RayGenCB"]["gDoCosineSampling"] = mDoCosSampling;
    rayGenVars["RayGenCB"]["gDoGI"] = mDoGI;
    rayGenVars["gWsPos"] = mpResManager->getTexture("WorldPosition");     
	rayGenVars["gWsNorm"] = mpResManager->getTexture("WorldNormal");
	rayGenVars["gMatDif"] = mpResManager->getTexture("MaterialDiffuse");
	rayGenVars["gOutput"] = outputTex;

    // Ray payload size is limited to 65 bytes, so pass directly as much data to the shader as
    // possible.
    for (auto hitVars : mpRayTracer->getHitVars(0)) {
        hitVars["GIClosestHitVars"]["gDoDirectShadows"] = mDoDirectShadows;
    }

    // TODO: should be 1 instead of 0, because it is hitgroup 1 that uses gEnvMap; but if set to 1,
    // the render doesn't converge and there are very bright pixels.
    auto missVars = mpRayTracer->getMissVars(0);
    // Color sampled by all rays that escape the scene without hitting anything. Constant buffer.
    missVars["gEnvMap"] = mpResManager->getTexture(ResourceManager::kEnvironmentMap);

    mpRayTracer->execute(pRenderContext, mpResManager->getScreenSize());
}

void DiffuseGIPass::renderGui(Gui* pGui) {
    int dirty = 0;

    dirty |= (int)pGui->addCheckBox(mDoDirectShadows ? "Shoot shadow rays" : "Don't shoot shadow rays", mDoDirectShadows);

    dirty |= (int)pGui->addCheckBox(mDoGI ? "Shoot GI rays" : "Don't shoot GI rays", mDoGI);

    dirty |= (int)pGui->addCheckBox(mDoCosSampling ? "Cosine-weighted hemisphere sampling" : "Uniform hemisphere sampling", mDoCosSampling);

	if (dirty) {
        setRefreshFlag();
    }
}