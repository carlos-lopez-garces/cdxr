#include "AccumulationPass.h"

namespace {
    const char *kAccumShader = "Shaders\\Accumulation.ps.hlsl";
};

AccumulationPass::SharedPtr AccumulationPass::create(const std::string &accumulationBuffer) {
    return SharedPtr(new AccumulationPass(accumulationBuffer));
}

bool AccumulationPass::initialize(RenderContext *pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;
    // Request a single texture of default format (RGBA32Float) and default size (screen sized).
    // The AccumulationPass accumulates multiple frames' data in this texture.
    mpResManager->requestTextureResource(mAccumChannel);

    mpResManager->setDefaultSceneName("Data/pink_room/pink_room.fscene");

    // State for rasterization pipeline.
    mpGfxState = Falcor::GraphicsState::create();

    mpAccumShader = FullscreenLaunch::create(kAccumShader);

    return true;
}