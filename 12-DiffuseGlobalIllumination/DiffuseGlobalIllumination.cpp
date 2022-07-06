#include "Falcor.h"
#include "../SharedUtils/RenderingPipeline.h"
#include "../SharedUtils/ResourceManager.h"
#include "../08-ThinLensCamera/Passes/ThinLensGBufferPass.h"
#include "../06-TemporalAccumulation/Passes/TemporalAccumulationPass.h"
#include "Passes/DiffuseGIPass.h"

int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPSTR lpCmdLine, _In_ int nShowCmd) {
    RenderingPipeline pipeline;

    pipeline.setPass(0, ThinLensGBufferPass::create());
    pipeline.setPass(1, DiffuseGIPass::create());
    pipeline.setPass(2, TemporalAccumulationPass::create(ResourceManager::kOutputChannel));

    SampleConfig config;
    config.windowDesc.title = "Diffuse GI";

    RenderingPipeline::run(&pipeline, config);
}