#include <chrono>
#include "JitteredGBufferPass.h"

namespace {
    const char *kGbufVertexShader = "CommonPasses\\gBuffer.vs.hlsl";
    const char *kGbufPixelShader = "CommonPasses\\gBuffer.ps.hlsl";
}

bool JitteredGBufferPass::initialize(RenderContext *pPenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;

    // Default format RGBA32Float and screen-sized.
    mpResManager->requestTextureResources({
        "WorldPosition",
        "WorldNormal",
        "MaterialDiffuse",
        "MaterialSpecRough",
        "MaterialExtraParams"
    });

    mpResManager->requestTextureResource(
        "Z-Buffer",
        // 24 normalized bits for depth, 8 for stencil.
        Falcor::ResourceFormat::D24UnormS8,
        ResourceManager::kDepthBufferFlags
    );

    mpResManager->setDefaultSceneName("Scenes\\PinkRoom\\pink_room.fscene");

    mpGfxState = Falcor::GraphicsState::create();

    // Rasterizer.
    mpRasterizer = RasterLaunch::createFromFiles(kGbufVertexShader, kGbufPixelShader);
    mpRasterizer->setScene(mpScene);

    auto currentTime = std::chrono::high_resolution_clock::now();
    auto timeInMilliSecs = std::chrono::time_point_cast<std::chrono::milliseconds>(currentTime);
    mPRNG = std::mt19937(uint32_t(timeInMilliSecs.time_since_epoch().count()));

    return true;
}