#pragma once
#include <random>
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"

class UnidirectionalPathTracingPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, UnidirectionalPathTracingPass> {
protected:
	RayLaunch::SharedPtr mpRayTracer;
    RtScene::SharedPtr mpScene;
	std::string mOutputBuffer;

	bool mDoCosSampling = true;

	uint32_t mFrameCount = 0x1337u;
	uint32_t mMaxBounces = 8;
	uint32_t mMinBouncesBeforeRussianRoulette = 3;

	UnidirectionalPathTracingPass(const std::string &outputBuffer) : ::RenderPass("Debug", "Debug Settings") {
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
    using SharedPtr = std::shared_ptr<UnidirectionalPathTracingPass>;

    using SharedConstPtr = std::shared_ptr<const UnidirectionalPathTracingPass>;

    static SharedPtr create(const std::string &outputBuffer) { return SharedPtr(new UnidirectionalPathTracingPass(outputBuffer)); }

    virtual ~UnidirectionalPathTracingPass() = default;
};
