#pragma once
#include "Falcor.h"
#include "../SharedUtils/RenderPass.h"

// Copies the selected texture of the G-Buffer to the output buffer and presents it to the screen.
class CopyPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, CopyPass> {
protected:
    // The name of the output buffer.
    std::string mOutChannel;

    Gui::DropdownList mDisplayableBuffers;  

    uint32_t mSelectedBuffer = 0xFFFFFFFFu;

	CopyPass(const std::string &outBuffer) : ::RenderPass("Copy-to-Output Pass", "Copy-to-Output Options"), mOutChannel(outBuffer) {}
	
    bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;

	void renderGui(Gui* pGui) override;

	void pipelineUpdated(ResourceManager::SharedPtr pResManager) override;

	void execute(RenderContext* pRenderContext) override;

	bool appliesPostprocess() override { return true; }

public:
    using SharedPtr = std::shared_ptr<CopyPass>;

	static SharedPtr create(const std::string &outBuffer) {
        return SharedPtr(new CopyPass(outBuffer));
    }

    virtual ~CopyPass() = default;
 };
