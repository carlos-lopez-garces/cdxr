#include "Falcor.h"
#include "../SharedUtils/RayLaunch.h"
#include "../SharedUtils/RenderPass.h"

class RayTracedAmbientOcclusionPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, RayTracedAmbientOcclusionPass> {
protected:
    RayLaunch::SharedPtr mpRayTracer;
    Falcor::RtScene::SharedPtr mpScene;

    // The AO radius determines a pixel's nearby geometry that participates in the pixel's AO calculation.
    float mAoRadius = 0.0f;
    // Used as initialization seed for the PRNG.
    uint32_t mFrameCount = 0;
    int32_t mNumRaysPerPixel = 1;

    RayTracedAmbientOcclusionPass() : RenderPass("Ray Traced Ambient Occlusion", "Ray Traced Ambient Occlusion Options") {}

    bool initialize(RenderContext *pRenderContext, ResourceManager::SharedPtr pResManager) override;
    void initScene(RenderContext *pRenderContext, Falcor::Scene::SharedPtr pScene) override;
    void execute(RenderContext *pRenderContext) override;
    void renderGui(Gui* pGui) override;

    bool requiresScene() override {
        return true;
    }

    bool usesRayTracing() override {
        return true;
    }

public:
    using SharedPtr = std::shared_ptr<RayTracedAmbientOcclusionPass>;

    static SharedPtr create() {
        return SharedPtr(new RayTracedAmbientOcclusionPass());
    }

    virtual ~RayTracedAmbientOcclusionPass() = default;
};