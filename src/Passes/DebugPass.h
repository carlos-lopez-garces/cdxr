#pragma once
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"

class DebugPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, DebugPass> {
protected:
	RayLaunch::SharedPtr mpRayTracer;
    RtScene::SharedPtr mpScene;
	std::string mOutputBuffer;

	bool mDoIndirectGI = true;
	bool mDoCosSampling = true;
	bool mDoDirectShadows = true;
	bool mDoGI = true;

	uint32_t mFrameCount = 0x1337u;

	DebugPass(const std::string &outputBuffer) : ::RenderPass("Debug", "Debug Settings") {
		mOutputBuffer = outputBuffer;
	}

    bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;

    void initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) override;

    void execute(RenderContext* pRenderContext) override;

	void renderGui(Gui* pGui) override;

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
    using SharedPtr = std::shared_ptr<DebugPass>;

    using SharedConstPtr = std::shared_ptr<const DebugPass>;

    static SharedPtr create(const std::string &outputBuffer) { return SharedPtr(new DebugPass(outputBuffer)); }

    virtual ~DebugPass() = default;
};
