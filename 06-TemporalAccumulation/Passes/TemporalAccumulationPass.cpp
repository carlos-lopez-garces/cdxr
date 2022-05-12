#include "TemporalAccumulationPass.h"

namespace {
    const char *kAccumShader = "Shaders\\Accumulation.ps.hlsl";
};

TemporalAccumulationPass::SharedPtr TemporalAccumulationPass::create(const std::string &accumulationBuffer) {
    return SharedPtr(new TemporalAccumulationPass(accumulationBuffer));
}

bool TemporalAccumulationPass::initialize(RenderContext *pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;
    // Request a single texture of default format (RGBA32Float) and default size (screen sized).
    // The TemporalAccumulationPass accumulates multiple frames' data in this texture.
    mpResManager->requestTextureResource(mAccumChannel);

    mpResManager->setDefaultSceneName("Data/pink_room/pink_room.fscene");

    // State for rasterization pipeline.
    mpGfxState = Falcor::GraphicsState::create();

    mpAccumShader = FullscreenLaunch::create(kAccumShader);

    return true;
}

void TemporalAccumulationPass::initScene(RenderContext *pRenderContext, Falcor::Scene::SharedPtr pScene) {
    // Reset some state because a new scene is going to be laoded.
    mNumFramesAccum = 0;

    mpScene = pScene;
    if (mpScene && mpScene->getActiveCamera()) {
        mpLastCameraMatrix = mpScene->getActiveCamera()->getViewMatrix();
    } 
}