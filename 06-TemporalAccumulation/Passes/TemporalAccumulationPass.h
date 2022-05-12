#pragma once
#include "../SharedUtils/FullscreenLaunch.h"
#include "../SharedUtils/RenderPass.h"

class TemporalAccumulationPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, TemporalAccumulationPass> {
protected:
    std::string mAccumChannel;

    uint32_t mNumFramesAccum;
    
    Falcor::Scene::SharedPtr mpScene;
    // Cameras belong to scenes; every scene defines its own cameras, one of which is active at 
    // any one moment. When loading a new scene, we need to adopt the scene's active camera.
    glm::mat4 mpLastCameraMatrix;

    // State for rasterization pipeline.
    Falcor::GraphicsState::SharedPtr mpGfxState;

    FullscreenLaunch::SharedPtr mpAccumShader;

    TemporalAccumulationPass(const std::string &accumulationBuffer) : RenderPass("Accumulation Pass", "Accumulation Pass Options") {
        mAccumChannel = accumulationBuffer;
    };

    bool initialize(RenderContext *pRenderContext, ResourceManager::SharedPtr pResManager) override;

    // Called when loading a new scene. Some state needs to be reset
    void initScene(RenderContext *pRenderContext, Falcor::Scene::SharedPtr pScene) override;

public:
    using SharedPtr = std::shared_ptr<TemporalAccumulationPass>;
    
    static SharedPtr create(const std::string &accumulationBuffer);

    bool requiresScene() override {
        return true;
    }
};