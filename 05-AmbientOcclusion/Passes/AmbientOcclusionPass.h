#include "Falcor.h"
#include "../SharedUtils/RayLaunch.h"
#include "../SharedUtils/RenderPass.h"

class AmbientOcclusionPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, AmbientOcclusionPass> {
protected:
    RayLaunch::SharedPtr mpRays;
    RtScene::SharedPtr mpScene;

    AmbientOcclusionPass() : RenderPass("Ray Traced Ambient Occlusion", "Ray Traced Ambient Occlusion Options") {}

    bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;
    void execute() override;
    void setScene() override;

    bool requiresScene() override {
        return true;
    }

    bool usesRayTracing() override {
        return true;
    }

public:
    using SharedPtr = std::shared_ptr<AmbientOcclusionPass>;

    static SharedPtr create() {
        return SharedPtr(new AmbientOcclusionPass());
    }

    virtual ~AmbientOcclusionPass() = default;
};