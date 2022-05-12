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

void TemporalAccumulationPass::execute(RenderContext *pRenderContext) {
    // The texture where the accumulation is done.
    Falcor::Texture::SharedPtr accumTexture = mpResManager->getTexture(mAccumChannel);

    // mDoAccumulation is set through the GUI to enable/disable temporal accumulation.
    if (!accumTexture || !mDoAccumulation) {
        return;
    }

    if (hasCameraMoved()) {
        // Reset state and start accumulation over.
        mNumFramesAccum = 0;
        // When hasCameraMoved() returns true, the scene and the active camera are 
        // guaranteed to exist.
        mpLastCameraMatrix = mpScene->getActiveCamera()->getViewMatrix();
    }

    // Execute the pixel shader, passing it down the last frame and accumulation texture.
    // The pixel shader will do a weighted combination of the last frame and the
    // accumulation texture to obtain an average.
    auto pixelShaderVars = mpAccumShader->getVars();
    pixelShaderVars["PerFrameCB"]["mNumFramesAccum"] = mNumFramesAccum++;
    pixelShaderVars["gLastFrame"] = mpLastFrame;
    pixelShaderVars["gCurFrame"] = accumTexture;
    mpAccumShader->execute(pRenderContext, mpGfxState);

    // blit copies a source SRV into a destination RTV.
    pRenderContext->blit(mpInternalFbo->getColorTexture(0)->getSRV(), accumTexture->getRTV());
    // Save the rendered frame to pass it down to the next frame's pixel shader.
    pRenderContext->blit(mpInternalFbo->getColorTexture(0)->getSRV(), mpLastFrame->getRTV());
}

bool TemporalAccumulationPass::hasCameraMoved() {
    // The camera has moved when the current view matrix is different from the previously
    // saved view matrix. The view matrix is saved right after the camera moves and when
    // a new scene is loaded.
    return mpScene
        && mpScene->getActiveCamera()
        && (mpLastCameraMatrix != mpScene->getActiveCamera()->getViewMatrix());
}