#include "Falcor.h"
#include "UnidirectionalPathTracingPass.h"
#include "../SharedUtils/ResourceManager.h"
#include "../SharedUtils/RayLaunch.h"

namespace {
    // Shader file.
    const char *kShaderFile = "Shaders\\PathTracing.rt.hlsl";

    // Entrypoints.
    const char *kEntryPointRayGen = "PathTracingRayGen";
    const char *kEntryPointPTClosestHit = "PTClosestHit";
    const char *kEntryPointPTAnyHit = "PTAnyHit";
    const char *kEntryPointPTMiss = "PTMiss";

    // Environment map file.
    const char* kEnvironmentMap = "MonValley_G_DirtRoad_3k.hdr";
};

bool UnidirectionalPathTracingPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;

    mpResManager->requestTextureResources({
        "PrimaryRayOriginOnLens",
        "PrimaryRayDirection",
        "WorldPosition",
        "WorldNormal",
        "WorldShadingNormal",
        "MaterialDiffuse",
        "MaterialEmissive",
        "DiffuseBRDF",
        "DiffuseLightIntensity",
        "SpecularBRDF",
    });
    mpResManager->requestTextureResource(mOutputBuffer);
    // mpResManager->requestTextureResource(ResourceManager::kEnvironmentMap);

    mpResManager->updateEnvironmentMap(kEnvironmentMap);
    mpResManager->setDefaultSceneName("Data/pink_room/pink_room.fscene");

    mpRayTracer = RayLaunch::create(kShaderFile, kEntryPointRayGen);
    // Ray type / hit group 0: path tracing rays.
    mpRayTracer->addMissShader(kShaderFile, kEntryPointPTMiss);
    mpRayTracer->addHitShader(kShaderFile, kEntryPointPTClosestHit, kEntryPointPTAnyHit);

    mpRayTracer->compileRayProgram();
    if (mpScene) {
        mpRayTracer->setScene(mpScene);
    }

    return true;
}


void UnidirectionalPathTracingPass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) {
    mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
    if (mpRayTracer) mpRayTracer->setScene(mpScene);
}

void UnidirectionalPathTracingPass::execute(RenderContext* pRenderContext) {
    Texture::SharedPtr diffuseBRDFTex = mpResManager->getClearedTexture("DiffuseBRDF", vec4(0.0f, 0.0f, 0.0f, 0.0f));
    Texture::SharedPtr diffuseLightIntensityTex = mpResManager->getClearedTexture("DiffuseLightIntensity", vec4(0.0f, 0.0f, 0.0f, 0.0f));
    Texture::SharedPtr specularBRDFTex = mpResManager->getClearedTexture("SpecularBRDF", vec4(0.0f, 0.0f, 0.0f, 0.0f));
    Texture::SharedPtr outputTex = mpResManager->getClearedTexture(mOutputBuffer, vec4(0.0f, 0.0f, 0.0f, 0.0f));
    Texture::SharedPtr matDiffuseTex = mpResManager->getTexture("MaterialDiffuse");

    if (!outputTex || !mpRayTracer || !mpRayTracer->readyToRender()) {
        return;
    }

    auto rayGenVars = mpRayTracer->getRayGenVars();
    rayGenVars["RayGenCB"]["gFrameCount"] = mFrameCount++;
    rayGenVars["RayGenCB"]["gMaxBounces"] = mMaxBounces;
    rayGenVars["RayGenCB"]["gMinBouncesBeforeRussianRoulette"] = mMinBouncesBeforeRussianRoulette;
    rayGenVars["RayGenCB"]["gTMin"] = mpResManager->getMinTDist();
    rayGenVars["RayGenCB"]["gTMax"] = FLT_MAX;
    rayGenVars["RayGenCB"]["gDoCosineSampling"] = mDoCosSampling;
    rayGenVars["gWsPos"] = mpResManager->getTexture("WorldPosition");     
	rayGenVars["gWsNorm"] = mpResManager->getTexture("WorldNormal");
    rayGenVars["gWsShadingNorm"] = mpResManager->getTexture("WorldShadingNormal");
	rayGenVars["gMatDif"] = matDiffuseTex;
    rayGenVars["gMatEmissive"] = mpResManager->getTexture("MaterialEmissive");
    rayGenVars["gRayOriginOnLens"] = mpResManager->getTexture("PrimaryRayOriginOnLens");
    rayGenVars["gPrimaryRayDirection"] = mpResManager->getTexture("PrimaryRayDirection");
    rayGenVars["gDiffuseBRDF"] = diffuseBRDFTex;
    rayGenVars["gDiffuseLightIntensity"] = diffuseLightIntensityTex;
    rayGenVars["gSpecularBRDF"] = specularBRDFTex;
	rayGenVars["gOutput"] = outputTex;

    // Set up variables for all hit shaders of the PT shader.
    for (auto ptHitVars : mpRayTracer->getHitVars(0)) {
        ptHitVars["gDiffuseBRDF"] = diffuseBRDFTex;
        // DEBUG: if you comment this out, the program doesn't break or crash.
        // DEBUG: a shader variable with name gDiffuseLightIntensity is indeed found in hit group 0.
        ptHitVars["gDiffuseLightIntensity"] = diffuseLightIntensityTex;
        ptHitVars["gSpecularBRDF"] = specularBRDFTex;
        rayGenVars["gMatDif"] = matDiffuseTex;
    }

    // TODO: should be 1 instead of 0, because it is hitgroup 1 that uses gEnvMap; but if set to 1,
    // the render doesn't converge and there are very bright pixels.
    auto PTMissVars = mpRayTracer->getMissVars(0);
    // Color sampled by all rays that escape the scene without hitting anything. Constant buffer.
    PTMissVars["gEnvMap"] = mpResManager->getTexture(ResourceManager::kEnvironmentMap);

    mpRayTracer->execute(pRenderContext, mpResManager->getScreenSize());
}

void UnidirectionalPathTracingPass::renderGui(Gui* pGui) {
    int dirty = 0;

    dirty |= (int)pGui->addCheckBox(mDoCosSampling ? "Cosine-weighted hemisphere sampling" : "Uniform hemisphere sampling", mDoCosSampling);

	if (dirty) {
        setRefreshFlag();
    }
}