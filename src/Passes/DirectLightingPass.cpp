#include "Falcor.h"
#include "DirectLightingPass.h"
#include "../SharedUtils/ResourceManager.h"
#include "../SharedUtils/RayLaunch.h"

namespace {
    // Shader file.
    const char *kShaderFile = "Shaders\\DirectLighting.rt.hlsl";

    // Entrypoints.
    const char *kEntryPointRayGen = "DirectLightingRayGen";
    const char *kEntryPointClosestHit = "DLClosestHit";
    const char *kEntryPointAnyHit = "DLAnyHit";
    const char *kEntryPointMiss = "DLMiss";
    const char *kEntryPointShadowClosestHit = "ShadowClosestHit";
    const char *kEntryPointShadowAnyHit = "ShadowAnyHit";
    const char *kEntryPointShadowMiss = "ShadowMiss";

    // Environment map file.
    const char* kEnvironmentMap = "MonValley_G_DirtRoad_3k.hdr";
};

bool DirectLightingPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;

    mpResManager->requestTextureResources({
        "PrimaryRayOriginOnLens",
        "PrimaryRayDirection",
        "MaterialDiffuse",
        "DiffuseBRDF",
        "SpecularBRDF",
        "DiffuseColor",
        "DirectL",
        "Le",
        "BRDFProbability"
    });
    mpResManager->requestTextureResource(mOutputBuffer);

    mpResManager->updateEnvironmentMap(kEnvironmentMap);
    mpResManager->setDefaultSceneName("Data/pink_room/pink_room.fscene");

    mpRayTracer = RayLaunch::create(kShaderFile, kEntryPointRayGen);
    // Ray type / hit group 0: path tracing rays.
    mpRayTracer->addMissShader(kShaderFile, kEntryPointMiss);
    mpRayTracer->addHitShader(kShaderFile, kEntryPointClosestHit, kEntryPointAnyHit);
    // Ray type / hit group 1: shadow rays.
    mpRayTracer->addMissShader(kShaderFile, kEntryPointShadowMiss);
    mpRayTracer->addHitShader(kShaderFile, kEntryPointShadowClosestHit, kEntryPointShadowAnyHit);

    mpRayTracer->compileRayProgram();
    if (mpScene) {
        mpRayTracer->setScene(mpScene);
    }

    return true;
}


void DirectLightingPass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) {
    mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
    if (mpRayTracer) mpRayTracer->setScene(mpScene);
}

void DirectLightingPass::execute(RenderContext* pRenderContext) {
    Texture::SharedPtr diffuseColorTex = mpResManager->getClearedTexture("DiffuseColor", vec4(0.0f, 0.0f, 0.0f, 0.0f));
    Texture::SharedPtr diffuseBRDFTex = mpResManager->getClearedTexture("DiffuseBRDF", vec4(0.0f, 0.0f, 0.0f, 0.0f));
    Texture::SharedPtr specularBRDFTex = mpResManager->getClearedTexture("SpecularBRDF", vec4(0.0f, 0.0f, 0.0f, 0.0f));
    Texture::SharedPtr outputTex = mpResManager->getClearedTexture(mOutputBuffer, vec4(0.0f, 0.0f, 0.0f, 0.0f));
    Texture::SharedPtr directLTex = mpResManager->getClearedTexture("DirectL", vec4(0.0f, 0.0f, 0.0f, 0.0f));
    Texture::SharedPtr leTex = mpResManager->getClearedTexture("Le", vec4(0.0f, 0.0f, 0.0f, 0.0f));
    Texture::SharedPtr brdfProbabilityTex = mpResManager->getClearedTexture("BRDFProbability", vec4(0.0f, 0.0f, 0.0f, 0.0f));

    if (!outputTex || !mpRayTracer || !mpRayTracer->readyToRender()) {
        return;
    }

    auto rayGenVars = mpRayTracer->getRayGenVars();
    rayGenVars["RayGenCB"]["gFrameCount"] = mFrameCount++;
    rayGenVars["RayGenCB"]["gMaxBounces"] = mMaxBounces;
    rayGenVars["RayGenCB"]["gTMin"] = mpResManager->getMinTDist();
    rayGenVars["RayGenCB"]["gTMax"] = FLT_MAX;
    rayGenVars["gRayOriginOnLens"] = mpResManager->getTexture("PrimaryRayOriginOnLens");
    rayGenVars["gPrimaryRayDirection"] = mpResManager->getTexture("PrimaryRayDirection");
    rayGenVars["gDiffuseBRDF"] = diffuseBRDFTex;
    rayGenVars["gSpecularBRDF"] = specularBRDFTex;
    rayGenVars["gDiffuseColor"] = diffuseColorTex;
    rayGenVars["gLe"] = leTex;
    rayGenVars["gDirectL"] = directLTex;
    rayGenVars["gBRDFProbability"] = brdfProbabilityTex;
	rayGenVars["gOutput"] = outputTex;

    // Set up variables for all hit shaders.
    for (auto dlHitVars : mpRayTracer->getHitVars(0)) {
        dlHitVars["gDiffuseBRDF"] = diffuseBRDFTex;
        dlHitVars["gSpecularBRDF"] = specularBRDFTex;
        dlHitVars["gDiffuseColor"] = diffuseColorTex;
        dlHitVars["gDirectL"] = directLTex;
        dlHitVars["gLe"] = leTex;
        dlHitVars["gBRDFProbability"] = brdfProbabilityTex;
    }

    // TODO: should be 1 instead of 0, because it is hitgroup 1 that uses gEnvMap; but if set to 1,
    // the render doesn't converge and there are very bright pixels.
    auto dlMissVars = mpRayTracer->getMissVars(0);
    // Color sampled by all rays that escape the scene without hitting anything. Constant buffer.
    dlMissVars["gEnvMap"] = mpResManager->getTexture(ResourceManager::kEnvironmentMap);
    dlMissVars["gDirectL"] = directLTex;

    mpRayTracer->execute(pRenderContext, mpResManager->getScreenSize());
}