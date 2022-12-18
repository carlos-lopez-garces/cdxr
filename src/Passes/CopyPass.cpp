#include "Falcor.h"
#include "CopyPass.h"

bool CopyPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
	mpResManager = pResManager;
	mpResManager->requestTextureResource(ResourceManager::kOutputChannel);
	mDisplayableBuffers.push_back({ -1, "< None >" });
    return true;
}

void CopyPass::renderGui(Gui* pGui) {
	pGui->addDropdown("Displayed", mDisplayableBuffers, mSelectedBuffer);
}

void CopyPass::execute(RenderContext* pRenderContext) { 
	Texture::SharedPtr outTex = mpResManager->getTexture(ResourceManager::kOutputChannel);
	if (!outTex) return;

	Texture::SharedPtr inTex = mpResManager->getTexture( mSelectedBuffer );

	if (!inTex || mSelectedBuffer == uint32_t(-1)) {
		pRenderContext->clearRtv(outTex->getRTV().get(), vec4(0.0f,0.0f,0.0f, 1.0f));
		return;
	}

	pRenderContext->blit(inTex->getSRV(), outTex->getRTV());
}


void CopyPass::pipelineUpdated(ResourceManager::SharedPtr pResManager) {
	if (!pResManager) return;
	mpResManager = pResManager;

	mDisplayableBuffers.clear();

	int32_t outputChannel = mpResManager->getTextureIndex(ResourceManager::kOutputChannel);

	for (uint32_t i = 0; i < mpResManager->getTextureCount(); i++) {
		if (i == outputChannel) continue;

		mDisplayableBuffers.push_back({ int32_t(i), mpResManager->getTextureName(i) });

		if (mSelectedBuffer == uint32_t(-1)) mSelectedBuffer = i;
	}

	if (mDisplayableBuffers.size() <= 0) {
		mDisplayableBuffers.push_back({ -1, "< None >" });
		mSelectedBuffer = uint32_t(-1);
	}
}