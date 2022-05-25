#include <random>
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/ResourceManager.h"
#include "../SharedUtils/RayLaunch.h"

class ThinLensGBufferPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, ThinLensGBufferPass> {
protected:
    RayLaunch::SharedPtr mpRayTracer;

    Falcor::RtScene::SharedPtr mpScene;

    // Mersenne Twister pseudo-random generator of 32-bit numbers with a state size of 19937 bits.
    std::mt19937 mPRNG;
    std::uniform_real_distribution<float> mRNGDistribution;
    bool mUseJitter;

    // Lens configuration.
    //
    // Use a pinhole camera by default or a thin lens approximation if true.
    bool mUseThinLens = false;
    float mLensRadius;
    float mFocalLength = 1.0f;
    float mFNumber = 32.0f;

    vec4 mBgColor;

    uint mFrameCount = 0;

    ThinLensGBufferPass() : ::RenderPass("Thin Lens Camera", "Thin Lens Camera Options") {}

    bool initialize(Falcor::RenderContext *pRenderContext, ResourceManager::SharedPtr pResManager) override;

    void execute(Falcor::RenderContext *pRenderContext) override;

public:
    using SharedPtr = std::shared_ptr<ThinLensGBufferPass>;

    static SharedPtr create() {
        return SharedPtr(new ThinLensGBufferPass());
    }

    virtual ~ThinLensGBufferPass() = default;
};