#include <chrono>
#include "JitteredGBufferPass.h"

namespace {
    const char *kGbufVertexShader = "Shaders\\GBuffer.vs.hlsl";
    const char *kGbufPixelShader = "Shaders\\GBuffer.ps.hlsl";
}

bool JitteredGBufferPass::initialize(RenderContext *pRenderContext, ResourceManager::SharedPtr pResManager) {
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

void JitteredGBufferPass::execute(RenderContext *pRenderContext) {
    Falcor::Fbo::SharedPtr outputFbo = mpResManager->createManagedFbo(
        {
            "WorldPosition",
            "WorldNormal",
            "MaterialDiffuse",
            "MaterialSpecRough",
            "MaterialExtraParams"
        },
        "Z-Buffer"
    );

    if (!outputFbo) {
        return;
    }

    if (mUseJitter && mpScene && mpScene->getActiveCamera()) {
        mFrameCount++;

        // Jitter the camera with random subpixel offsets of size up to half a pixel.
        float xJitter = mRNGDistribution(mPRNG) - 0.5f;
        float xSubpixelOffset = xJitter / float(outputFbo->getWidth());
        float yJitter = mRNGDistribution(mPRNG) - 0.5f;
        float ySubpixelOffset = yJitter / float(outputFbo->getHeight());
        mpScene->getActiveCamera()->setJitter(xSubpixelOffset, ySubpixelOffset);
    }

    pRenderContext->clearFbo(outputFbo.get(), vec4(0, 0, 0, 0), 1.0f, 0);
    pRenderContext->clearUAV(outputFbo->getColorTexture(2)->getUAV().get(), vec4(mBgColor, 1.0f));

    mpRasterizer->execute(pRenderContext, mpGfxState, outputFbo);
}

void JitteredGBufferPass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) {
	if (pScene) {
        mpScene = pScene;
    }

	if (mpRasterizer) {
        mpRasterizer->setScene(mpScene);
    }
}

void JitteredGBufferPass::renderGui(Gui* pGui) {
	int dirty = 0;

	dirty |= (int)pGui->addCheckBox(mUseJitter ? "Camera jitter enabled" : "Camera jitter disabled", mUseJitter);

	if (dirty) setRefreshFlag();
}