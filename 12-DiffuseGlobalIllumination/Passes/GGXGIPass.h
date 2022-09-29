#pragma once
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"

class GGXGIPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, GGXGIPass> {
protected:
	RayLaunch::SharedPtr mpRayTracer;
    RtScene::SharedPtr mpScene;
	std::string mOutputBuffer;

	bool mDoIndirectGI = true;
	bool mDoDirectGI = true;
    const int32_t mMaxRayDepth = 8;
    int32_t mRayDepth = 1;

	uint32_t mFrameCount = 0x1337u;

	GGXGIPass(const std::string &outputBuffer) : ::RenderPass("Diffuse GI Ray", "Diffuse GI Settings") {
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
    using SharedPtr = std::shared_ptr<GGXGIPass>;

    using SharedConstPtr = std::shared_ptr<const GGXGIPass>;

    static SharedPtr create(const std::string &outputBuffer) { return SharedPtr(new GGXGIPass(outputBuffer)); }

    virtual ~GGXGIPass() = default;
};
