#pragma once
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"

class EnvLightProbeGBufferPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, EnvLightProbeGBufferPass> {
protected:
	RayLaunch::SharedPtr mpRayTracer;
	RtScene::SharedPtr mpScene;

	vec3 mBgColor = vec3(0.5f, 0.5f, 1.0f);
	Texture::SharedPtr mLightProbe;
	bool mUseLightProbe = true;

	EnvLightProbeGBufferPass() : ::RenderPass("Light Probe G-Buffer", "Light Probe G-Buffer Settings") {}

	bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;
	void execute(RenderContext* pRenderContext) override;
	void initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) override;

	bool requiresScene() override  { 
		return true;
	}
	
	bool usesRayTracing() override {
		return true;
	}

	bool usesEnvironmentMap() override {
		return true; 
	}

public:
	using SharedPtr = std::shared_ptr<EnvLightProbeGBufferPass>;
	using SharedConstPtr = std::shared_ptr<const EnvLightProbeGBufferPass>;

	static SharedPtr create() { return SharedPtr(new EnvLightProbeGBufferPass()); }
	virtual ~EnvLightProbeGBufferPass() = default;
};
