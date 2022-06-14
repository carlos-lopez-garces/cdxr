#include "Falcor.h"
#include "../SharedUtils/RenderingPipeline.h"
#include "../SharedUtils/ResourceManager.h"
#include "../06-TemporalAccumulation/Passes/TemporalAccumulationPass.h"
#include "../08-ThinLensCamera/Passes/ThinLensGBufferPass.h"
#include "Passes/LambertianReflectionAndShadowsPass.h"

int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPSTR lpCmdLine, _In_ int nShowCmd) {
	RenderingPipeline pipeline;

	pipeline.setPass(0, ThinLensGBufferPass::create());
	pipeline.setPass(1, LambertianReflectionAndShadowsPass::create());
	pipeline.setPass(2, TemporalAccumulationPass::create(ResourceManager::kOutputChannel));

	Falcor::SampleConfig config;
	config.windowDesc.resizableWindow = true;
	config.windowDesc.title = "Lambertian reflection and shadows";

	RenderingPipeline::run(&pipeline, config);
}