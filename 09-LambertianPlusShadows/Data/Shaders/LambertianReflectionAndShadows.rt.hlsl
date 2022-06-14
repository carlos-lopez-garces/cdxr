// From Falcor.
#include "HostDeviceSharedMacros.h"
#include "HostDeviceData.h"           
import Raytracing;
import ShaderCommon;
import Shading;     
import Lights;
#include "AlphaTesting.hlsli"
#include "PRNG.hlsli"
#include "Sampling.hlsli"

// G-Buffer.
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gMatDif;
RWTexture2D<float4> gOutput;

[shader("raygeneration")]
void LambertAndShadowsRayGen() {
    // The DispatchRaysIndex() intrinsic gives the index of this thread's ray. We use it to
	// identify the pixel.
	uint2 pixelIndex = DispatchRaysIndex().xy;

	// The DispatchRaysDimensions() intrinsic gives the number of rays launched and corresponds
	// to RayLaunch::execute()'s 2nd parameter: the total number of pixels.
	uint2 pixelCount = DispatchRaysDimensions().xy;

    // Textures support 2D indexing.
    float4 worldPosition = gPos[pixelIndex];
    float4 worldNormal = gNorm[pixelIndex];
    float4 diffuseMatColor = gMatDif[pixelIndex];

    // Background color for when the ray escapes the scene without hitting anything.
    float pixelColor = diffuseMatColor.rgb;

    if (worldPosition.w != 0.0f) {

    }

    gOutput[pixelIndex] = float4(color, 1.0f);
}