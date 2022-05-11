#include "RayTracedGBufferPass.h"

namespace {
    // Shader filepath. This shader file contains entry points for the ray generation,
    // miss, any hit, and closest hit shaders.
    const char *kFileRayTrace = "Shaders\\rayTracedGBuffer.rt.hlsl";

    // Entrypoints for various shaders contained in kFileRayTrace.
    const char *kEntryPointRayGen = "GBufferRayGen";
    const char *kEntryPointMiss = "PrimaryMiss";
    const char *kEntryPrimaryClosestHit = "PrimaryClosestHit";
    const char *kEntryPrimaryAnyHit = "PrimaryAnyHit";
};

bool RayTracedGBufferPass::initialize(Falcor::RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
    // RenderPass member. Used for getting rendering resources.
    mpResManager = pResManager;

    // Request one texture per GBuffer of the default format, RGBA32F, and default size, screen sized.
    mpResManager->requestTextureResources({
        "WorldPosition",
        "WorldNormal",
        "MaterialDiffuse",
        "MaterialSpecRough",
        "MaterialExtraParams",
        "Emissive"
    });

    // For launching draw calls using a specified shader file and entrypoint.
    mpRays = RayLaunch::create(kFileRayTrace, kEntryPointRayGen);
    mpRays->addMissShader(kFileRayTrace, kEntryPointMiss);
    mpRays->addHitShader(kFileRayTrace, kEntryPrimaryClosestHit, kEntryPrimaryAnyHit);

    // Compile shaders.
    mpRays->compileRayProgram();
    
    // Specify the scene to load, if any; set the default scene in case no particular scene is specified.
    mpResManager->setDefaultSceneName("Data/pink_room/pink_room.fscene");
    if (mpScene) {
        mpRays->setScene(mpScene);
    }

    return true;
}