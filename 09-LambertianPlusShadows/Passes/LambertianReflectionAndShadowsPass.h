#pragma once
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"

class LambertianReflectionAndShadowsPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, LambertianReflectionAndShadowsPass> {
protected
	RayLaunch::SharedPtr mpRayTracer;

    RtScene::SharedPtr mpScene;
    
	uint32_t mMinTSelector = 1;

	LambertianReflectionAndShadowsPass() : ::RenderPass("Lambertian Reflection and Shadows", "Lambertian Reflection and Shadows Settings") {}

    bool initialize(Falcor::RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;

    void initScene(Falcor::RenderContext* pRenderContext, Scene::SharedPtr pScene) override;

    void execute(RenderCFalcor::ontext* pRenderContext) override;


	bool requiresScene() override {
        return true; 
    }

	bool usesRayTracing() override {
        return true; 
    }

public:
    using SharedPtr = std::shared_ptr<LambertianReflectionAndShadowsPass>;
    using SharedConstPtr = std::shared_ptr<const LambertianReflectionAndShadowsPass>;

    static SharedPtr create() { return SharedPtr(new LambertianReflectionAndShadowsPass()); }
    virtual ~LambertianReflectionAndShadowsPass() = default;
};
