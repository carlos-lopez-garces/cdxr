#include "HostDeviceSharedMacros.h"
import Raytracing;
import ShaderCommon;
import Shading;
#include "AlphaTesting.hlsli"
#include "Sampling.hlsli"

// G-Buffer.
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gMatDif;
RWTexture2D<float4> gMatSpec;
RWTexture2D<float4> gMatExtra;
// Environment map;
Texture2D<float4> gEnvMap;

cbuffer RayGenCB {
	float2 gPixelJitter;
	float gFocalLength;
	float gLensRadius;
	uint gFrameCount;
};

struct RayPayload {
	bool dummyValue;
};

[shader("raygeneration")]
void ThinLensGBufferRayGen() {
	// The DispatchRaysIndex() intrinsic gives the index of this thread's ray. We use it to
	// identify the pixel.
	uint2 pixelIndex = DispatchRaysIndex().xy;

	// The DispatchRaysDimensions() intrinsic gives the number of rays launched and corresponds
	// to RayLaunch::execute()'s 2nd parameter: the total number of pixels.
	uint2 pixelCount = DispatchRaysDimensions().xy;

	// The interval [0,1) is subdivided uniformly into subintervals of size 1/pixelCount. pixelIndex
	// locates the subinterval that corresponds to this pixel. Without jitter, pixelCenter corresponds
	// to the left endpoint of the subinterval. With gPixelJitter, which is in [-0.5,0.5], the center
	// moves into the previous subinterval, if negative, or into the subinterval, if positive, by up
	// to half a pixel.
	float2 pixelCenter = (pixelIndex + gPixelJitter) / pixelCount;

	// Map pixelCenter to [-1,1]x[1,-1]. Note that before the y-coordinate transformation, the image is
	// upside-down.  
	float2 ndc = float2(2, -2) * pixelCenter + float2(-1, 1);

	// The view space basis is (gCamera.cameraU, gCamera.cameraV, gCamera.cameraW). The primary ray's
	// direction is a linear combination of this basis with coefficients given by the pixel center's
	// NDC coordinates.
	float3 worldSpaceRayDir = ndc.x*gCamera.cameraU + ndc.y*gCamera.cameraV + gCamera.cameraW;

	// // Dividing by length(gCamera.cameraW) doesn't change the direction of worldSpaceRayDir, it just
	// // shortens the vector, making worldSpaceRayDir have length 1 in the camera's w-axis.
	worldSpaceRayDir /= length(gCamera.cameraW);

	// The origin of the ray is the camera's world-space position and the focal point lies on the line
	// along the ray's world-space direction vector, a gFocalLength distance away from the origin. 
	float3 focalPoint = gCamera.posW + gFocalLength*worldSpaceRayDir;

	// Sample a point on the lens at random, in polar coordinates, (theta, radius) in [0,2PI]x[0,gLensRadius].
	float PI = 3.14159265f;
	uint seed = initRand(pixelIndex.x + pixelIndex.y*pixelCount.x, gFrameCount, 16);
	float2 lensSamplePoint = float2(2*PI*nextRand(seed), gLensRadius*nextRand(seed));

	// Move the ray's origin from the world-space position of the camera to the sample point on the lens.
	float3 rayOriginOnLens = gCamera.posW + lensSamplePoint.y*cos(lensSamplePoint.x)*normalize(gCamera.cameraU) + lensSamplePoint.y*sin(lensSamplePoint.x)*normalize(gCamera.cameraV);

	// The ray.
	RayDesc ray;
	ray.Origin = rayOriginOnLens;
	ray.Direction = normalize(focalPoint - rayOriginOnLens);
	ray.TMin = 0.0f;
	// Hits beyond this ray.Origin + ray.TMax*ray.Direction are ignored.
	ray.TMax = 1e+38f;

	RayPayload payload = {false};

	// gRtScene is supplied by the framework and represents the ray acceleration structure.
	// RAY_FLAG_CULL_BACK_FACING_TRIANGLES is for ignoring hits on triangle back faces.
    // The 4th parameter is the hit group, #0. A hit group is an intersection, a closest-hit shader,
    // and an any-hit shader. Hit group #0 corresponds to primary rays.
    // hitProgramCount is supplied by the framework and is the number of hit groups that exist.
	TraceRay(
		gRtScene,
		RAY_FLAG_CULL_BACK_FACING_TRIANGLES,
		0xFF,
		0,
		hitProgramCount,
		0,
		ray,
		payload
	); 
}

// BuiltInTriangleIntersectionAttributes just contains float2 barycentrics. See 
// https://docs.microsoft.com/en-us/windows/win32/direct3d12/intersection-attributes.
[shader("closesthit")]
void PrimaryClosestHit(inout RayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
	uint2 pixelIndex = DispatchRaysIndex().xy;

	// PrimitiveIndex() is an object introspection intrinsic that returns
    // the identifier of the current primitive.
	VertexOut vsOut = getVertexAttributes(PrimitiveIndex(), attributes);

	// Supplied by Falcor.
	ShadingData shadeData = prepareShadingData(vsOut, gMaterial, gCamera.posW, 0);

	gWsPos[pixelIndex] = float4(shadeData.posW, 1.0f);
	gWsNorm[pixelIndex] = float4(shadeData.N, 0.0f);
	gMatDif[pixelIndex] = float4(shadeData.diffuse, shadeData.opacity);
	gMatSpec[pixelIndex] = float4(shadeData.specular, shadeData.linearRoughness);
	// Includes Index of Refraction and whether the material is double-sided.
	gMatExtra[pixelIndex] = float4(shadeData.IoR, shadeData.doubleSidedMaterial ? 1.f : 0.f, 0.f, 0.f);
}

[shader("anyhit")]
void PrimaryAnyHit(inout RayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
	if (alphaTestFails(attributes)) {
        // The intersected geometry is transparent. Acceleration structure traversal
        // resumes after IgnoreHit().
        IgnoreHit();   
    }
}

cbuffer MissShaderCB {
	float3 gBgColor;
	bool gUseEnvMap;
};

[shader("miss")]
void PrimaryMiss(inout RayPayload payload) {
	uint2 pixelIndex = DispatchRaysIndex().xy;

	float2 envMapDimensions;
	gEnvMap.GetDimensions(envMapDimensions.x, envMapDimensions.y);

	float2 uv = WorldToLatitudeLongitude(WorldRayDirection());

	if (gUseEnvMap) {
		gMatDif[pixelIndex] = float4(gEnvMap[uint2(uv * envMapDimensions)].rgb, 1.0f);
	} else {
		gMatDif[pixelIndex] = float4(gBgColor, 1.0f);
	}
}