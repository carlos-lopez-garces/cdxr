#pragma once
#include <random>
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/ResourceManager.h"
#include "../SharedUtils/RasterLaunch.h"

// The JitteredGBufferPass implements antialiasing of geometric edges by multiplying a random jitter matrix
// and the projection matrix every frame, effectively shifting the center of every pixel by a subpixel distance
// less than half a pixel, thereby potentially changing the fragment that is visible through the pixel from frame
// to frame. The pass populates a rasterized G-Buffer of world-space position and normal where each entry is the
// position and normal of the fragment that passes the z-buffer test for the corresponding pixel. The jittered
// G-Buffer can then be used, for example, by a RayTracedAmbientOcclusionPass to spawn AO rays whose origin is the
// world-space position stored in the G-Buffer.
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

    void initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) override;

    void renderGui(Gui* pGui) override;

    bool requiresScene() override { 
        return true;
    }
	
    bool usesRasterization() override { 
        return true;
    }

public:
    using SharedPtr = std::shared_ptr<JitteredGBufferPass>;

    static SharedPtr create() {
        return SharedPtr(new JitteredGBufferPass());
    }

    virtual ~JitteredGBufferPass() = default;
};