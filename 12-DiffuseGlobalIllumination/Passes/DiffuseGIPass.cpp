#include "Falcor.h"
#include "DiffuseGIPass.h"
#include "../SharedUtils/ResourceManager.h"
#include "../SharedUtils/RayLaunch.h"

namespace {
    // Shader file.
    const char *kShaderFile = "Shaders\\DiffuseGI.rt.hlsl";

    // Entrypoints.
    const char *kEntryPointRayGen = "DiffuseGIRayGen";
    const char *kEntryPointShadowClosestHit = "ShadowClosestHit";
    const char *kEntryPointShadowAnyHit = "ShadowAnyHit";
    const char *kEntryPointShadowMiss = "ShadowMiss";
};

bool DiffuseGIPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;

    mpResManager->requestTextureResources({
        "WorldPosition", "WorldNormal", "MaterialDiffuse"
    });
    mpResManager->requestTextureResource(ResourceManager::kOutputChannel);

    mpResManager->setDefaultSceneName("Data/pink_room/pink_room.fscene");

    mpRayTracer = RayLaunch::create(kShaderFile, kEntryPointRayGen);

    // Ray type 1: shadow rays.
    mpRayTracer->addHitShader(kShaderFile, kEntryPointShadowClosestHit, kEntryPointShadowAnyHit);
    mpRayTracer->addMissShader(kShaderFile, kEntryPointShadowMiss);

    mpRayTracer->compileRayProgram();
    if (mpScene) {
        mpRayTracer->setScene(mpScene);
    }

    return true;
}


void DiffuseGIPass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) {
    mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
}

void DiffuseGIPass::execute(RenderContext* pRenderContext) {
    Texture::SharedPtr outputTex = mpResManager->getClearedTexture(ResourceManager::kOutputChannel, vec4(0.0f, 0.0f, 0.0f, 0.0f));

    if (!outputTex || !mpRayTracer || !mpRayTracer->readyToRender()) {
        return;
    }

    auto rayGenVars = mpRayTracer->getRayGenVars();
    rayGenVars["RayGenCB"]["gFrameCount"] = mFrameCount++;
    rayGenVars["RayGenCB"]["gTMin"] = mpResManager->getMinTDist();
    rayGenVars["RayGenCB"]["gTMax"] = FLT_MAX;
    rayGenVars["gPos"] = mpResManager->getTexture("WorldPosition");     
	rayGenVars["gNorm"] = mpResManager->getTexture("WorldNormal");
	rayGenVars["gMatDif"] = mpResManager->getTexture("MaterialDiffuse");
	rayGenVars["gOutput"] = outputTex;

    mpRayTracer->execute(pRenderContext, mpResManager->getScreenSize());
}

void DiffuseGIPass::renderGui(Gui* pGui) {

}