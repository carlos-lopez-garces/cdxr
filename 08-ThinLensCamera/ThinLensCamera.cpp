#include "Falcor.h"
#include "../SharedUtils/RenderingPipeline.h"
#include "../SharedUtils/ResourceManager.h"
#include "../05-AmbientOcclusion/Passes/RayTracedAmbientOcclusionPass.h"
#include "../06-TemporalAccumulation/Passes/TemporalAccumulationPass.h"
#include "Passes/ThinLensGBufferPass.h"

int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPSTR lpCmdLine, _In_ int nShowCmd) {
	RenderingPipeline pipeline;

	pipeline.setPass(0, ThinLensGBufferPass::create());
	pipeline.setPass(1, RayTracedAmbientOcclusionPass::create());
	pipeline.setPass(2, TemporalAccumulationPass::create(ResourceManager::kOutputChannel));

	Falcor::SampleConfig config;
	config.windowDesc.resizableWindow = true;
	config.windowDesc.title = "Thin lens camera";

	RenderingPipeline::run(&pipeline, config);
}