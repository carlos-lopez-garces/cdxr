#include "Falcor.h"
#include "../SharedUtils/RenderingPipeline.h"
#include "../CommonPasses/CopyToOutputPass.h"
#include "Passes/RayTracedGBufferPass.h"

int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPSTR lpCmdLine, _In_ int nShowCmd) {
	RenderingPipeline *pipeline = new RenderingPipeline();

	pipeline->setPass(0, RayTracedGBufferPass::create());
	pipeline->setPass(1, CopyToOutputPass::create());

	SampleConfig config;
	config.windowDesc.title = "Raytraced GBuffer";
	config.windowDesc.resizableWindow = true;

	RenderingPipeline::run(pipeline, config);
}