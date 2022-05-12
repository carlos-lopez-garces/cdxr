#include "../SharedUtils/FullscreenLaunch.h"
#include "../SharedUtils/RenderPass.h"

class AccumulationPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, AccumulationPass> {
protected:
    std::string mAccumChannel;

    // State for rasterization pipeline.
    Falcor::GraphicsState::SharedPtr mpGfxState;

    FullscreenLaunch::SharedPtr mpAccumShader;

    AccumulationPass(const std::string &accumulationBuffer) : RenderPass("Accumulation Pass", "Accumulation Pass Options") {
        mAccumChannel = accumulationBuffer;
    };

    bool initialize(RenderContext *pRenderContext, ResourceManager::SharedPtr pResManager);

public:
    using SharedPtr = std::shared_ptr<AccumulationPass>;
    
    static SharedPtr create(const std::string &accumulationBuffer);
};