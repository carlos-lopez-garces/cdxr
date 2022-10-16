#define _SILENCE_EXPERIMENTAL_FILESYSTEM_DEPRECATION_WARNING 1
#include "Falcor.h"
#include "../SharedUtils/RenderingPipeline.h"
#include "../SharedUtils/ResourceManager.h"
#include "../08-ThinLensCamera/Passes/ThinLensGBufferPass.h"
#include "../06-TemporalAccumulation/Passes/TemporalAccumulationPass.h"
#include "Passes/DiffuseGIPass.h"
#include "Passes/GGXGIPass.h"
#include "Passes/UnidirectionalPathTracingPass.h"
#include "Passes/ToneMappingPass.h"
#include "../CommonPasses/LightProbeGBufferPass.h"

int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPSTR lpCmdLine, _In_ int nShowCmd) {
    RenderingPipeline pipeline;

    // pipeline.setPass(0, ThinLensGBufferPass::create());
    pipeline.setPass(0, LightProbeGBufferPass::create());
    // pipeline.setPass(1, DiffuseGIPass::create("HDROutput"));
    // pipeline.setPass(1, UnidirectionalPathTracingPass::create("HDROutput"));
    pipeline.setPass(1, GGXGIPass::create("HDROutput"));
    pipeline.setPass(2, TemporalAccumulationPass::create("HDROutput"));
    pipeline.setPass(3, ToneMappingPass::create("HDROutput", ResourceManager::kOutputChannel));

    SampleConfig config;
    config.windowDesc.title = "Diffuse GI and tone mapping";

    RenderingPipeline::run(&pipeline, config);
}