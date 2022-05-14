#pragma once
#include <random>
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/ResourceManager.h"
#include "../SharedUtils/RasterLaunch.h"

class JitteredGBufferPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, JitteredGBufferPass> {
protected:
    bool mUseJitter = true;

    uint32_t mFrameCount = 0;

    vec3 mBgColor = vec3(0.5f, 0.5f, 1.0f);

    Falcor::GraphicsState::SharedPtr mpGfxState;

    RasterLaunch::SharedPtr mpRasterizer;

    Falcor::Scene::SharedPtr mpScene;

    // Mersenne Twister pseudo-random generator of 32-bit numbers with a state size of 19937 bits.
    std::mt19937 mPRNG;
    // Samples a uniform distribution over [0,1].
    std::uniform_real_distribution<float> mRNGDistribution;

    JitteredGBufferPass() : ::RenderPass("Jittered G-Buffer Antialiasing", "Jittered G-Buffer Antialiasing Options") {}

    bool initialize(RenderContext *pRenderContext, ResourceManager::SharedPtr pResManager) override;

    void execute(RenderContext *pRenderContext) override;

public:
    using SharedPtr = std::shared_ptr<JitteredGBufferPass>;

    static SharedPtr create() {
        return SharedPtr(new JitteredGBufferPass());
    }

    virtual ~JitteredGBufferPass() = default;
};