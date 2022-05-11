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

void RayTracedGBufferPass::execute(RenderContext* pRenderContext) {
    if (!mpRays || !mpRays->readyToRender()) {
        return;
    }

    // Load GBuffer textures, cleared to black. We write directly to them using UAVs.
    Falcor::Texture::SharedPtr worldPosition = mpResManager->getClearedTexture("WorldPosition", vec4(0, 0, 0, 0));
    Falcor::Texture::SharedPtr worldNormal = mpResManager->getClearedTexture("WorldNormal", vec4(0, 0, 0, 0));
    Falcor::Texture::SharedPtr materialDiffuse = mpResManager->getClearedTexture("MaterialDiffuse", vec4(0, 0, 0, 0));
    Falcor::Texture::SharedPtr materialSpecRough = mpResManager->getClearedTexture("MaterialSpecRough", vec4(0, 0, 0, 0));
    Falcor::Texture::SharedPtr materialExtraParams = mpResManager->getClearedTexture("MaterialExtraParams", vec4(0, 0, 0, 0));
    Falcor::Texture::SharedPtr materialEmissive = mpResManager->getClearedTexture("Emissive", vec4(0, 0, 0, 0));

    // Set miss shader #0 variables.
    auto missVars = mpRays->getMissVars(0);
    // Rays that escape the scene sample this color.
    missVars["MissShaderCB"]["gBgColor"] = mBgColor;
    missVars["gMatDif"] = materialDiffuse;

    // Set hit group #0 variables used in closest-hit and any-hit shaders. Each pVars
    // corresponds to a geometry instance.
    for (auto pVars : mpRays->getHitVars(0)) {
        // Bind textures to hit shaders for this geometry instance.
        pVars["gWsPos"] = worldPosition;
        pVars["gWsNorm"] = worldNormal;
        pVars["gMatDif"] = materialDiffuse;
        pVars["gMatSpec"] = materialSpecRough;
        pVars["gMatExtra"] = materialExtraParams;
        pVars["gMatEmissive"] = materialEmissive;
    }

    // Launch and trace rays.
    mpRays->execute(pRenderContext, mpResManager->getScreenSize());
}

void RayTracedGBufferPass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) {
	mpScene = std::dynamic_pointer_cast<RtScene>(pScene);

	if (mpRays) {
        mpRays->setScene(mpScene);
    }
}