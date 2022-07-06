#pragma once
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"

// Applies tone mapping post-processing, delegating the work to Falcor's ToneMapping class.
class ToneMappingPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, ToneMappingPass> {
protected:
    // The name of the render target produced by the previous pass. Assumed to be HDR due to the
    // use of an HDR environment map.
    std::string mInChannel;

    // The name of the tone mapped result.
    std::string mOutChannel;

    // Falcor's ToneMapping class.
    ToneMapping::SharedPtr mpToneMapper;

    GraphicsState::SharedPtr mpGfxState;

	ToneMappingPass(const std::string &inBuffer, const std::string &outBuffer) 
        : ::RenderPass("Tone Mapping", "Tone Mapping Settings"), mInChannel(inBuffer), mOutChannel(outBuffer)
    {}

    bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;

    void execute(RenderContext* pRenderContext) override;

	void renderGui(Gui* pGui) override;

	bool appliesPostprocess() override {
		return true;
	}

public:
    using SharedPtr = std::shared_ptr<ToneMappingPass>;

    using SharedConstPtr = std::shared_ptr<const ToneMappingPass>;

    static SharedPtr create(const std::string &inBuffer, const std::string &outBuffer) { 
        return SharedPtr(new ToneMappingPass(inBuffer, outBuffer));
    }

    virtual ~ToneMappingPass() = default;
};
