#include <chrono>
#include "ThinLensGBufferPass.h"

namespace {
    // Shader.
    const char *kShaderFile = "Shaders\\ThinLensGBuffer.rt.hlsl";

    // Shader entrypoints;
    const char* kEntryPointRayGen = "ThinLensGBufferRayGen";
	const char* kEntryPointMiss0 = "PrimaryMiss";
	const char* kEntryPrimaryAnyHit = "PrimaryAnyHit";
	const char* kEntryPrimaryClosestHit = "PrimaryClosestHit";

    // Environment map file.
    const char* kEnvironmentMap = "MonValley_G_DirtRoad_3k.hdr";
};

bool ThinLensGBufferPass::initialize(Falcor::RenderContext *pRenderContext, ResourceManager::SharedPtr pResManager) {
    mpResManager = pResManager;

    // Request G-Buffer textures.
    mpResManager->requestTextureResources({
        // Channels.
        "WorldPosition",
        "WorldNormal",
        "WorldShadingNormal",
        "MaterialDiffuse",
        "MaterialSpecRough",
        "MaterialExtraParams", 
        "MaterialEmissive"
    });

    mpResManager->updateEnvironmentMap(kEnvironmentMap);

    mpResManager->setDefaultSceneName("Scenes\\PinkRoom\\pink_room.fscene");

    // Set up the ray tracer.
    mpRayTracer = RayLaunch::create(kShaderFile, kEntryPointRayGen);
    mpRayTracer->addMissShader(kShaderFile, kEntryPointMiss0);
    mpRayTracer->addHitShader(kShaderFile, kEntryPrimaryClosestHit, kEntryPrimaryAnyHit);
    mpRayTracer->compileRayProgram();
    if (mpScene) {
        mpRayTracer->setScene(mpScene);
    }

    // Set up the pseudo-random number generator.
    auto currentTime = std::chrono::high_resolution_clock::now();
    auto timeInMilliSecs = std::chrono::time_point_cast<std::chrono::milliseconds>(currentTime);
    mPRNG = std::mt19937(uint32_t(timeInMilliSecs.time_since_epoch().count()));

    // A larger GUI?
    setGuiSize(ivec2(250, 300));
    return true;
}

void ThinLensGBufferPass::execute(Falcor::RenderContext *pRenderContext) {
    if (!mpRayTracer || !mpRayTracer->readyToRender()) {
        return;
    }

    mLensRadius = mFocalLength / (2.0f * mFNumber);

    // Load G-Buffer textures.
    Falcor::Texture::SharedPtr worldSpacePosition = mpResManager->getClearedTexture("WorldPosition", vec4(0, 0, 0, 0));
    Falcor::Texture::SharedPtr worldSpaceNormal = mpResManager->getClearedTexture("WorldNormal", vec4(0, 0, 0, 0));
    Falcor::Texture::SharedPtr worldSpaceShadingNormal = mpResManager->getClearedTexture("WorldShadingNormal", vec4(0, 0, 0, 0));
    Falcor::Texture::SharedPtr materialDiffuse = mpResManager->getClearedTexture("MaterialDiffuse", vec4(0, 0, 0, 0));
    Falcor::Texture::SharedPtr materialSpecularRoughness = mpResManager->getClearedTexture("MatSpecRough", vec4(0, 0, 0, 0));
    Falcor::Texture::SharedPtr materialExtraParams = mpResManager->getClearedTexture("MaterialExtraParams", vec4(0, 0, 0, 0));
    Falcor::Texture::SharedPtr materialEmissive = mpResManager->getClearedTexture("MaterialEmissive", vec4(0, 0, 0, 0));

    // Lens parameters are relevant when computing primary ray origins, so they go in the ray
    // generation shader.
    auto rayGenVars = mpRayTracer->getRayGenVars();
    rayGenVars["RayGenCB"]["gFrameCount"] = mFrameCount++;
    rayGenVars["RayGenCB"]["gLensRadius"] = mUseThinLens ? mLensRadius : 0.0f;
    rayGenVars["RayGenCB"]["gFocalLength"] = mFocalLength;

    // Set up variables for all hit shaders.
    for (auto hitVars : mpRayTracer->getHitVars(0)) {
        hitVars["gWsPos"] = worldSpacePosition;
        hitVars["gWsNorm"] = worldSpaceNormal;
        hitVars["gWsShadingNorm"] = worldSpaceShadingNormal;
        hitVars["gMatDif"] = materialDiffuse;
        hitVars["gMatSpec"] = materialSpecularRoughness;
        hitVars["gMatExtra"] = materialExtraParams;
        hitVars["gMatEmissive"] = materialEmissive;
    }

    auto missVars = mpRayTracer->getMissVars(0);
    // Color sampled by all rays that escape the scene without hitting anything. Constant buffer.
    missVars["MissShaderCB"]["gBgColor"] = mBgColor;
    missVars["MissShaderCB"]["gUseEnvMap"] = mUseEnvMap;
    missVars["gMatDif"] = materialDiffuse;
    missVars["gEnvMap"] = mpResManager->getTexture(ResourceManager::kEnvironmentMap);

    if (mUseJitter && mpScene && mpScene->getActiveCamera()) {
        // Jitter the camera with random subpixel offsets of size up to half a pixel.
        float xJitter = mRNGDistribution(mPRNG) - 0.5f;
        // The size of the viewport can be gotten from any of the G-Buffers.
        float xSubpixelOffset = xJitter / float(worldSpacePosition->getWidth());
        float yJitter = mRNGDistribution(mPRNG) - 0.5f;
        float ySubpixelOffset = yJitter / float(worldSpacePosition->getHeight());
        mpScene->getActiveCamera()->setJitter(xSubpixelOffset, ySubpixelOffset);

        // Just the jitter size, not the subpixel offset.
        rayGenVars["RayGenCB"]["gPixelJitter"] = vec2(xJitter, yJitter);
    }

    mpRayTracer->execute(pRenderContext, mpResManager->getScreenSize());
}

void ThinLensGBufferPass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) {
	mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
	if (mpRayTracer) {
        mpRayTracer->setScene(mpScene);
    }
}

void ThinLensGBufferPass::renderGui(Gui* pGui) {
	int dirty = 0;

	dirty |= (int)pGui->addCheckBox(mUseThinLens ? "Thin lens camera" : "Pinhole camera", mUseThinLens);
	if (mUseThinLens) { 
		pGui->addText("     ");
        dirty |= (int)pGui->addFloatVar("Focal length", mFocalLength, 0.01f, FLT_MAX, 0.01f, true);
		pGui->addText("     ");
        dirty |= (int)pGui->addFloatVar("f-number", mFNumber, 1.0f, 128.0f, 0.01f, true);
        pGui->addText("     ");
	}

    if (mpScene) {
        pGui->addText("     ");

        // Choose among the preconfigured cameras available in the scene description file.
        dirty |= (int)pGui->addIntVar("Active camera", mActiveCameraId, 0, mpScene->getCameraCount()-1, 1, true);
        mpScene->setActiveCamera(mActiveCameraId);
        pGui->addText("     ");

        // Export and save the scene as an .fscene file.
        if (pGui->addButton("Save scene")) {
            std::string filename = "./saved_scene.fscene";
            Falcor::SceneExporter::saveScene(filename, mpScene);
        }
    }

	dirty |= (int)pGui->addCheckBox(mUseJitter ? "Jitter" : "No jitter", mUseJitter);

	dirty |= (int)pGui->addCheckBox(mUseEnvMap ? "Environment map" : "Background color", mUseEnvMap);

	if (dirty) {
        setRefreshFlag();
    }
}