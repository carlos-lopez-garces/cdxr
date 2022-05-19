#include "Falcor.h"
#include "../SharedUtils/RenderingPipeline.h"
#include "../05-AmbientOcclusion/Passes/RayTracedAmbientOcclusionPass.h"
#include "../06-TemporalAccumulation/Passes/TemporalAccumulationPass.h"
#include "Passes/JitteredGBufferPass.h"

int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPSTR lpCmdLine, _In_ int nShowCmd) {
    RenderingPipeline pipeline;

    // The JitteredGBufferPass produces a G-Buffer of world-space position and normal. Each frame samples
    // the scene through a randomly shifted point in projection space, resulting in a different fragment
    // being sampled from frame to frame.
    pipeline.setPass(0, JitteredGBufferPass::create());

    // The RayTracedAmbientOcclusionPass reads the origin of AO rays from the jittered G-Buffer, so the
    // AO computation is done for a different primary intersection point every frame. The varying primary
    // intersection point is what gets rid of aliasing.
    pipeline.setPass(1, RayTracedAmbientOcclusionPass::create());

    // Reduce noise.
    pipeline.setPass(2, TemporalAccumulationPass::create(ResourceManager::kOutputChannel));

    SampleConfig config;
    config.windowDesc.fullScreen = false;
	config.windowDesc.title = "Antialiasing using jittered camera samples";

    RenderingPipeline::run(&pipeline, config);
}