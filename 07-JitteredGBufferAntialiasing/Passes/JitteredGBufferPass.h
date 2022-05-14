#pragma once
#include <random>
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/ResourceManager.h"
#include "../SharedUtils/RasterLaunch.h"

class JitteredGBufferPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, JitteredGBufferPass> {
protected:
    Falcor::GraphicsState::SharedPtr mpGfxState;

    RasterLaunch::SharedPtr mpRasterizer;

    Falcor::Scene::SharedPtr mpScene;

    // Mersenne Twister pseudo-random generator of 32-bit numbers with a state size of 19937 bits.
    std::mt19937 mPRNG;

    JitteredGBufferPass() : ::RenderPass("Jittered G-Buffer Antialiasing", "Jittered G-Buffer Antialiasing Options") {}

    bool initialize(RenderContext *pPenderContext, ResourceManager::SharedPtr pResManager) override;

public:
    using SharedPtr = std::shared_ptr<JitteredGBufferPass>;

    static SharedPtr create() {
        return SharedPtr(new JitteredGBufferPass());
    }

    virtual ~JitteredGBufferPass() = default;
};