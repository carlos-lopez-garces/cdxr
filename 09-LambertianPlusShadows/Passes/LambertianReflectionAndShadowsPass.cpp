#include "LambertianReflectionAndShadowsPass.h"

namespace {
    // Shader.
    const char *kShaderFile = "Shaders\\LambertianReflectionAndShadows.rt.hlsl";

    // Shader entrypoints;
    const char* kEntryPointRayGen = "LambertAndShadowsRayGen";
	const char* kEntryPointMiss0 = "ShadowMiss";
	const char* kEntryPointAnyHit = "ShadowAnyHit";
	const char* kEntryPointClosestHit = "ShadowClosestHit";
};

bool LambertianReflectionAndShadowsPass::initialize(Falcor::RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;
    mpResManager->requestTextureResources({
        "WorldPosition", "WorldNormal", "MaterialDiffuse"
    });
    mpResManager->requestTextureResource(ResourceManager::kOutputChannel);

    mpResManager->setDefaultSceneName("Scenes\\PinkRoom\\pink_room.fscene");

    mpRayTracer = RayLaunch::create(kShaderFile, kEntryPointRayGen);
    mpRayTracer->addMissShader(kShaderFile, kEntryPointMiss0);
    mpRayTracer->addHitShader(kShaderFile, kEntryPointClosestHit, kEntryPointAnyHit);
    mpRayTracer->compileRayProgram();
    if (mpScene) {
        mpRayTracer->setScene(mpScene);
    }

    return true;
}

void LambertianReflectionAndShadowsPass::execute(Falcor::RenderContext* pRenderContext) {
    Texture::SharedPtr outputTex = mpResManager->getClearedTexture(ResourceManager::kOutputChannel, vec4(0.0f, 0.0f, 0.0f, 0.0f));

    if (!outputTex || !mpRayTracer || !mpRayTracer->readyToRender()) {
        return;
    }

    auto rayGenVars = mpRayTracer->getRayGenVars();
    rayGenVars["RayGenCB"]["gMinT"] = mpResManager->getMinTDist();
    rayGenVars["RayGenCB"]["gFrameCount"] = mFrameCount++;
    rayGenVars["RayGenCB"]["gSampleOnlyOneLight"] = mSampleOnlyOneLight;
    rayGenVars["RayGenCB"]["gShadows"] = mShadows;
    rayGenVars["gPos"] = mpResManager->getTexture("WorldPosition");     
	rayGenVars["gNorm"] = mpResManager->getTexture("WorldNormal");
	rayGenVars["gMatDif"] = mpResManager->getTexture("MaterialDiffuse");
	rayGenVars["gOutput"] = outputTex;

    mpRayTracer->execute(pRenderContext, mpResManager->getScreenSize());
}

void LambertianReflectionAndShadowsPass::initScene(Falcor::RenderContext* pRenderContext, Scene::SharedPtr pScene) {
    mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
	if (mpRayTracer) {
        mpRayTracer->setScene(mpScene);
    }
}

void LambertianReflectionAndShadowsPass::renderGui(Gui* pGui) {
	int dirty = 0;

    dirty |= (int)pGui->addCheckBox(mShadows ? "Shoot shadow rays" : "Don't shoot shadow rays", mShadows);

    dirty |= (int)pGui->addCheckBox(mSampleOnlyOneLight ? "Sample one light at random" : "Sample every light", mSampleOnlyOneLight);

	if (dirty) {
        setRefreshFlag();
    }
}