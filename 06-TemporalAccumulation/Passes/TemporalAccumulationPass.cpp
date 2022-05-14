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

    // A fullscreen pass is a rasterization draw call that requires no scene. No vertex shader
    // is involved.
    mpAccumShader = FullscreenLaunch::create(kAccumShader);

    return true;
}

void TemporalAccumulationPass::initScene(RenderContext *pRenderContext, Falcor::Scene::SharedPtr pScene) {
    // Reset some state because a new scene is going to be loaded.
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

        // There's no need to clear or otherwise reset the accumulation texture: since
        // the accumulated value's weight is mNumFramesAccum and mNumFramesAccum is being
        // reset to 0, the accumulated value will have no contribution to the presented
        // frame; since the value from the frame produced by the RayTracedAmbientOcclusionPass
        // has a weight of 1, the presented frame will simply be that of
        // RayTracedAmbientOcclusionPass and accumulation indeed starts over from that frame.
        mNumFramesAccum = 0;

        // When hasCameraMoved() returns true, the scene and the active camera are 
        // guaranteed to exist.
        mpLastCameraMatrix = mpScene->getActiveCamera()->getViewMatrix();
    }

    // Execute the pixel shader, passing it down the last frame and accumulation texture.
    // The pixel shader will do a weighted combination of the last frame and the
    // accumulation texture to obtain an average.
    auto pixelShaderVars = mpAccumShader->getVars();
    pixelShaderVars["PerFrameCB"]["gNumFramesAccum"] = mNumFramesAccum++;
    // The last frame is the frame produced by the RayTracedAmbientOcclusionPass.
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

void TemporalAccumulationPass::stateRefreshed() {
	mNumFramesAccum = 0;
}

void TemporalAccumulationPass::resize(uint32_t width, uint32_t height) {
    mpLastFrame = Falcor::Texture::create2D(
        width, height, Falcor::ResourceFormat::RGBA32Float, 1, 1, nullptr, ResourceManager::kDefaultFlags
    );

    mpInternalFbo = ResourceManager::createFbo(width, height, ResourceFormat::RGBA32Float);
    mpGfxState->setFbo(mpInternalFbo);

    // Start accumulation over.
    mNumFramesAccum = 0;
}

void TemporalAccumulationPass::renderGui(Gui* pGui) {
    pGui->addText((std::string("Accumulating buffer:   ") + mAccumChannel).c_str());
    pGui->addText("");

    if (pGui->addCheckBox(mDoAccumulation ? "Accumulating samples temporally" : "No temporal accumulation", mDoAccumulation)) {
		mNumFramesAccum = 0;
        setRefreshFlag();
    }

	pGui->addText("");
	pGui->addText((std::string("Frames accumulated: ") + std::to_string(mNumFramesAccum)).c_str());
}