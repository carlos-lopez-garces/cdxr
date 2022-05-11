#include "../SharedUtils/RenderingPipeline.h"
#include "../03-RasterGBuffer/Passes/SimpleGBufferPass.h"
#include "../03-RasterGBuffer/Passes/CopyToOutputPass.h"
#include "Passes/RayTracedAmbientOcclusionPass.h"

int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPSTR lpCmdLine, _In_ int nShowCmd) {
	RenderingPipeline pipeline;

	pipeline.setPass(0, SimpleGBufferPass::create());
	pipeline.setPass(1, RayTracedAmbientOcclusionPass::create());

	SampleConfig config;
	config.windowDesc.fullScreen = false;
	config.windowDesc.title = "Hybrid rasterized and ray traced ambient occlusion";

	RenderingPipeline::run(&pipeline, config);
}