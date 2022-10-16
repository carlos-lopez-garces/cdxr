#include "ToneMappingPass.h"

bool ToneMappingPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
	if (!pResManager) return false;

	mpResManager = pResManager;
	mpResManager->requestTextureResources({ mInChannel, mOutChannel });

	mpResManager->setDefaultSceneName("Data/pink_room/pink_room.fscene");

    // This class delegates all the work to Falcor's ToneMapping class.
	mpToneMapper = ToneMapping::create(ToneMapping::Operator::Clamp);

	mpGfxState = GraphicsState::create();

	return true;
}

void ToneMappingPass::execute(RenderContext* pRenderContext) {
	if (!mpResManager) return;
   
    // Get render target produced by the previous pass. It is assumed that this is an HDR render,
	// due to the use of an HDR environment map.
    Texture::SharedPtr renderTargetToToneMap = mpResManager->getTexture(mInChannel);

    // Tone mapped result.
	Fbo::SharedPtr toneMappedFbo = mpResManager->createManagedFbo({ mOutChannel });

	// You can push multiple graphics contexts to a stack and the top one will be the active one.
    // It is said that Falcor's tone mapper has unintended effects on the graphics context, so we
    // push one, execute the tone mapper, and then pop it to activate the original context again.
	pRenderContext->pushGraphicsState(mpGfxState);
    mpToneMapper->execute(pRenderContext, renderTargetToToneMap, toneMappedFbo);
	pRenderContext->popGraphicsState();
}

void ToneMappingPass::renderGui(Gui* pGui) {
	mpToneMapper->renderUI(pGui, nullptr); 
}