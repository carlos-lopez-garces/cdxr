#pragma once
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"

class RayTracedGBufferPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, RayTracedGBufferPass> {
protected:
    // For launching draw calls using a specified shader file and entrypoint.
    RayLaunch::SharedPtr mpRays;

    Falcor::RtScene::SharedPtr mpScene;

    // Rays that escape the scene sample this (background) color in the miss shader.
    vec3 mBgColor = vec3(0.5f, 0.5f, 1.0f);

    RayTracedGBufferPass() : RenderPass("Ray Traced G-Buffer", "Ray Traced G-Buffer Options") {}

    // Requests textures for the GBuffer to the resource manager, sets the default scene,
    // and sets the shaders in the RayLaunch.
    bool initialize(Falcor::RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;

    // Binds the GBuffer textures to the shaders and launches and traces rays.
    void execute(Falcor::RenderContext* pRenderContext) override;

    void initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) override;

    bool requiresScene() override {
        return true;
    }

	bool usesRayTracing() override {
        return true;
    }

public:
    using SharedPtr = std::shared_ptr<RayTracedGBufferPass>;

    static SharedPtr create() {
        return SharedPtr(new RayTracedGBufferPass());
    }

    virtual ~RayTracedGBufferPass() = default;
};