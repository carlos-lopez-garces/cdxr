#include "Falcor.h"
#include "../SharedUtils/RayLaunch.h"
#include "../SharedUtils/RenderPass.h"

class RayTracedAmbientOcclusionPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, RayTracedAmbientOcclusionPass> {
protected:
    RayLaunch::SharedPtr mpRays;
    Falcor::RtScene::SharedPtr mpScene;

    float mAoRadius = 0.0f;

    RayTracedAmbientOcclusionPass() : RenderPass("Ray Traced Ambient Occlusion", "Ray Traced Ambient Occlusion Options") {}

    bool initialize(RenderContext *pRenderContext, ResourceManager::SharedPtr pResManager) override;
    void initScene(RenderContext *pRenderContext, Falcor::Scene::SharedPtr pScene) override;
    void execute() override;

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