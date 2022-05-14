#include "Falcor.h"
#include "../SharedUtils/RenderingPipeline.h"
#include "../03-RasterGBuffer/Passes/SimpleGBufferPass.h"
#include "../05-AmbientOcclusion/Passes/RayTracedAmbientOcclusionPass.h"
#include "Passes/TemporalAccumulationPass.h"

/**
 * Temporal accumulation for reducing noise. A frame produced by random ray tracing sampling may
 * differ substantially from the previous one. That's the cause of what we perceive as dynamic noise.
 * 
 * A temporal accumulation pass follows the ray tracing pass (the ray traced ambient occlusion pass,
 * for example) to compute a weighted running average of the pixel's value. The output back buffer 
 * is saved by this pass as an accumulation texture. The frame produced by the ray tracing pass is
 * then used to update the accumulation texture to then present it to the screen. The pixel's new
 * value in the accumulation texture will be a weighted average of the accumulated value and the
 * value from the ray tracing pass; the old accumulated value's weight will be the number of frames
 * accumulated so far, while the new value's weight will simply be 1.
 * 
 * The accumulation texture remains valid as long as the camera doesn't move and the scene remains
 * unchanged. Once the camera moves or the scene changes, accumulation must start over; starting over
 * involves resetting the accumulated frame counter to 0. There's no need to clear or reset the
 * accumulation texture: the accumulated value's weight will be 0 because the frame counter has been
 * reset to 0. It's easy to detect when the camera moves: simply keep around the last frame's view
 * matrix and compare it with the current frame's.
 */
int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPSTR lpCmdLine, _In_ int nShowCmd) {
	RenderingPipeline pipeline;

	pipeline.setPass(0, SimpleGBufferPass::create());
	pipeline.setPass(1, RayTracedAmbientOcclusionPass::create());
	pipeline.setPass(2, TemporalAccumulationPass::create(ResourceManager::kOutputChannel));

	SampleConfig config;
	config.windowDesc.fullScreen = false;
	config.windowDesc.title = "Temporal accumulation of frames for reducing noise";

	RenderingPipeline::run(&pipeline, config);
}