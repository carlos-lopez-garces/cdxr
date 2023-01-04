#pragma once
#include <random>
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"

class DirectLightingPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, DirectLightingPass> {
protected:
	RayLaunch::SharedPtr mpRayTracer;
    RtScene::SharedPtr mpScene;
	std::string mOutputBuffer;

	uint32_t mFrameCount = 0x1337u;
	uint32_t mMaxBounces = 8;
	uint32_t mMinBouncesBeforeRussianRoulette = 3;

	DirectLightingPass(const std::string &outputBuffer) : ::RenderPass("Direct Lighting", "Direct Lighting Settings") {
		mOutputBuffer = outputBuffer;
	}

    bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;

    void initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) override;

    void execute(RenderContext* pRenderContext) override;

	bool requiresScene() override { 
		return true;
	}

	bool usesRayTracing() override {
		return true;
	}

	bool usesEnvironmentMap() override {
		return true;
	}

public:
    using SharedPtr = std::shared_ptr<DirectLightingPass>;

    using SharedConstPtr = std::shared_ptr<const DirectLightingPass>;

    static SharedPtr create(const std::string &outputBuffer) { return SharedPtr(new DirectLightingPass(outputBuffer)); }

    virtual ~DirectLightingPass() = default;
};
