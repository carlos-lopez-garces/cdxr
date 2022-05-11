#pragma once
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"

class RayTracedGBufferPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, RayTracedGBufferPass> {
protected:
    // For launching draw calls using a specified shader file and entrypoint.
    RayLaunch::SharedPtr mpRays;

    Falcor::RtScene::SharedPtr mpScene;

    RayTracedGBufferPass() : RenderPass("Ray Traced G-Buffer", "Ray Traced G-Buffer Options") {}

    bool initialize(Falcor::RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;
};