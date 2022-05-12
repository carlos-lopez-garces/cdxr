#pragma once
#include "../SharedUtils/FullscreenLaunch.h"
#include "../SharedUtils/RenderPass.h"

// Temporal accumulation of frames takes place as long as the camera doesn't move or the
// scene changes.
class TemporalAccumulationPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, TemporalAccumulationPass> {
protected:
    // The ResourceManager refers to textures by channel name;
    std::string mAccumChannel;

    // Number of frames that have been accumulated so far. It gets restarted every time the
    // camera moves or when a new scene is loaded.
    uint32_t mNumFramesAccum;
    
    Falcor::Scene::SharedPtr mpScene;
    // Cameras belong to scenes; every scene defines its own cameras, one of which is active at 
    // any one moment. When loading a new scene or when the camera has moved, we need to save the
    // active camera's view matrix because we use it to detect when the accumulation texture is 
    // no longer valid and we need to start it over.
    glm::mat4 mpLastCameraMatrix;

    // State for rasterization pipeline.
    Falcor::GraphicsState::SharedPtr mpGfxState;

    // FBO, or Frame Buffer Object, is OpenGL terminology for the collection of color and
    // depth/stencil buffers.
    Falcor::Fbo::SharedPtr mpInternalFbo;

    FullscreenLaunch::SharedPtr mpAccumShader;

    Falcor::Texture::SharedPtr mpLastFrame;

    bool mDoAccumulation;

    TemporalAccumulationPass(const std::string &accumulationBuffer) : RenderPass("Accumulation Pass", "Accumulation Pass Options") {
        mAccumChannel = accumulationBuffer;
    };

    bool initialize(RenderContext *pRenderContext, ResourceManager::SharedPtr pResManager) override;

    // Called when loading a new scene. Some state needs to be reset
    void initScene(RenderContext *pRenderContext, Falcor::Scene::SharedPtr pScene) override;

    void execute(RenderContext *pRenderContext) override;

    // Temporal accumulation starts over when the camera moves. 
    bool hasCameraMoved();

public:
    using SharedPtr = std::shared_ptr<TemporalAccumulationPass>;
    
    static SharedPtr create(const std::string &accumulationBuffer);

    bool requiresScene() override {
        return true;
    }
};