ShadingData simplePrepareShadingData(VertexOut v, MaterialData m, float3 camPosW)
{
	ShadingData sd = initShadingData();

    ExplicitLodTextureSampler lodSampler = { 0 };  // Specify the tex lod/mip to use here

	// Sample the diffuse texture and apply the alpha test
	float4 baseColor = sampleTexture(m.resources.baseColor, m.resources.samplerState, v.texC, m.baseColor, EXTRACT_DIFFUSE_TYPE(m.flags), lodSampler);
	sd.opacity = m.baseColor.a;

	sd.posW = v.posW;
	sd.uv = v.texC;
	sd.V = normalize(camPosW - v.posW);
	sd.N = normalize(v.normalW);
	sd.B = normalize(v.bitangentW - sd.N * (dot(v.bitangentW, sd.N)));
	sd.T = normalize(cross(sd.B, sd.N));

	// Sample the spec texture
	float4 spec = sampleTexture(m.resources.specular, m.resources.samplerState, v.texC, m.specular, EXTRACT_SPECULAR_TYPE(m.flags), lodSampler);
	if (EXTRACT_SHADING_MODEL(m.flags) == ShadingModelMetalRough)
	{
		sd.diffuse = lerp(baseColor.rgb, float3(0), spec.b);
		sd.specular = lerp(float3(0.04f), baseColor.rgb, spec.b);
		sd.linearRoughness = spec.g;
	}
	else // if (EXTRACT_SHADING_MODEL(m.flags) == ShadingModelSpecGloss)
	{
		sd.diffuse = baseColor.rgb;
		sd.specular = spec.rgb;
		sd.linearRoughness = 1 - spec.a;
	}

	sd.linearRoughness = max(0.08, sd.linearRoughness); // Clamp the roughness so that the BRDF won't explode
	sd.roughness = sd.linearRoughness * sd.linearRoughness;
    sd.emissive = sampleTexture(m.resources.emissive, m.resources.samplerState, v.texC, float4(m.emissive, 1), EXTRACT_EMISSIVE_TYPE(m.flags), lodSampler).rgb;
    sd.IoR = m.IoR;
	sd.doubleSidedMaterial = EXTRACT_DOUBLE_SIDED(m.flags);

	// We're not applying normal mapping on 2ndary surfaces; saves quite a bit of cost
	//applyNormalMap(m, sd, lodSampler);
	sd.NdotV = dot(sd.N, sd.V);

	// Flip the normal if it's backfacing
	if (sd.NdotV <= 0 && sd.doubleSidedMaterial)
	{
		sd.N = -sd.N;
		sd.NdotV = -sd.NdotV;
	}

	return sd;
}

// Encapsulates a bunch of Falcor stuff into one simpler function. 
//    -> This can only be called within a closest hit or any hit shader
ShadingData getHitShadingData(BuiltInTriangleIntersectionAttributes attribs, float3 cameraPos )
{
	// Run a pair of Falcor helper functions to compute important data at the current hit point
	VertexOut  vsOut = getVertexAttributes(PrimitiveIndex(), attribs);
	return simplePrepareShadingData(vsOut, gMaterial, cameraPos);
}

float probabilityToSampleDiffuse(float3 difColor, float3 specColor)
{
	float lumDiffuse = max(0.01f, luminance(difColor.rgb));
	float lumSpecular = max(0.01f, luminance(specColor.rgb));
	return lumDiffuse / (lumDiffuse + lumSpecular);
}

// A work-around function because some DXR drivers seem to have broken atan2() implementations
float atan2_WAR(float y, float x)
{
	if (x > 0.f)
		return atan(y / x);
	else if (x < 0.f && y >= 0.f)
		return atan(y / x) + M_PI;
	else if (x < 0.f && y < 0.f)
		return atan(y / x) - M_PI;
	else if (x == 0.f && y > 0.f)
		return M_PI / 2.f;
	else if (x == 0.f && y < 0.f)
		return -M_PI / 2.f;
	return 0.f; // x==0 && y==0 (undefined)
}

// Convert our world space direction to a (u,v) coord in a latitude-longitude spherical map
float2 wsVectorToLatLong(float3 dir)
{
	float3 p = normalize(dir);

	// atan2_WAR is a work-around due to an apparent compiler bug in atan2
	float u = (1.f + atan2_WAR(p.x, -p.z) * M_1_PI) * 0.5f;
	float v = acos(p.y) * M_1_PI;
	return float2(u, v);
}
struct IndirectRayPayload


{
	float3 color;    // The (returned) color in the ray's direction
	uint   rndSeed;  // Our random seed, so we pick uncorrelated RNGs along our ray
	uint   rayDepth; // What is the depth of our current ray?
};

float3 shootIndirectRay(float3 rayOrigin, float3 rayDir, float minT, uint curPathLen, uint seed, uint curDepth)
{
	// Setup our indirect ray
	RayDesc rayColor;
	rayColor.Origin = rayOrigin;  // Where does it start?
	rayColor.Direction = rayDir;  // What direction do we shoot it?
	rayColor.TMin = minT;         // The closest distance we'll count as a hit
	rayColor.TMax = 1.0e38f;      // The farthest distance we'll count as a hit

	// Initialize the ray's payload data with black return color and the current rng seed
	IndirectRayPayload payload;
	payload.color = float3(0, 0, 0);
	payload.rndSeed = seed;
	payload.rayDepth = curDepth + 1;

	// Trace our ray to get a color in the indirect direction.  Use hit group #1 and miss shader #1
	TraceRay(gRtScene, 0, 0xFF, 1, hitProgramCount, 1, rayColor, payload);

	// Return the color we got from our ray
	return payload.color;
}

[shader("miss")]
void IndirectMiss(inout IndirectRayPayload rayData)
{
	// Load some information about our lightprobe texture
	float2 dims;
	gEnvMap.GetDimensions(dims.x, dims.y);

	// Convert our ray direction to a (u,v) coordinate
	float2 uv = wsVectorToLatLong(WorldRayDirection());

	// Load our background color, then store it into our ray payload
	rayData.color = gEnvMap[uint2(uv * dims)].rgb;
}

[shader("anyhit")]
void IndirectAnyHit(inout IndirectRayPayload rayData, BuiltInTriangleIntersectionAttributes attribs)
{
	// Is this a transparent part of the surface?  If so, ignore this hit
	if (alphaTestFails(attribs))
		IgnoreHit();
}

float3 lambertianDirect(inout uint rndSeed, float3 hit, float3 norm, float3 difColor)
{
	// Pick a random light from our scene to shoot a shadow ray towards
	int lightToSample = min(int(nextRand(rndSeed) * gLightsCount), gLightsCount - 1);

	// Query the scene to find info about the randomly selected light
	float distToLight;
	float3 lightIntensity;
	float3 toLight;
	getLightData(lightToSample, hit, toLight, lightIntensity, distToLight);

	// Compute our lambertion term (L dot N)
	float LdotN = saturate(dot(norm, toLight));

	// Shoot our shadow ray to our randomly selected light
	float shadowMult = float(gLightsCount) * shootShadowRay(hit, toLight, gMinT, distToLight);

	// Return the Lambertian shading color using the physically based Lambertian term (albedo / pi)
	return shadowMult * LdotN * lightIntensity * difColor / M_PI;
}

float3 lambertianIndirect(inout uint rndSeed, float3 hit, float3 norm, float3 difColor, uint rayDepth)
{
	// Shoot a randomly selected cosine-sampled diffuse ray.
	float3 L = getCosHemisphereSample(rndSeed, norm);
	float3 bounceColor = shootIndirectRay(hit, L, gMinT, 0, rndSeed, rayDepth);

	// Accumulate the color: (NdotL * incomingLight * difColor / pi) 
	// Probability of sampling:  (NdotL / pi)
	return bounceColor * difColor;
}

float3 ggxDirect(inout uint rndSeed, float3 hit, float3 N, float3 V, float3 dif, float3 spec, float rough)
{
	// Pick a random light from our scene to shoot a shadow ray towards
	int lightToSample = min(int(nextRand(rndSeed) * gLightsCount), gLightsCount - 1);

	// Query the scene to find info about the randomly selected light
	float distToLight;
	float3 lightIntensity;
	float3 L;
	getLightData(lightToSample, hit, L, lightIntensity, distToLight);

	// Compute our lambertion term (N dot L)
	float NdotL = saturate(dot(N, L));

	// Shoot our shadow ray to our randomly selected light
	float shadowMult = float(gLightsCount) * shootShadowRay(hit, L, gMinT, distToLight);

	// Compute half vectors and additional dot products for GGX
	float3 H = normalize(V + L);
	float NdotH = saturate(dot(N, H));
	float LdotH = saturate(dot(L, H));
	float NdotV = saturate(dot(N, V));

	// Evaluate terms for our GGX BRDF model
	float  D = ggxNormalDistribution(NdotH, rough);
	float  G = ggxSchlickMaskingTerm(NdotL, NdotV, rough);
	float3 F = schlickFresnel(spec, LdotH);

	// Evaluate the Cook-Torrance Microfacet BRDF model
	//     Cancel out NdotL here & the next eq. to avoid catastrophic numerical precision issues.
	float3 ggxTerm = D*G*F / (4 * NdotV /* * NdotL */);

	// Compute our final color (combining diffuse lobe plus specular GGX lobe)
	return shadowMult * lightIntensity * ( /* NdotL * */ ggxTerm + NdotL * dif / M_PI);
}

float3 ggxIndirect(inout uint rndSeed, float3 hit, float3 N, float3 noNormalN, float3 V, float3 dif, float3 spec, float rough, uint rayDepth)
{
	// We have to decide whether we sample our diffuse or specular/ggx lobe.
	float probDiffuse = probabilityToSampleDiffuse(dif, spec);
	float chooseDiffuse = (nextRand(rndSeed) < probDiffuse);

	// We'll need NdotV for both diffuse and specular...
	float NdotV = saturate(dot(N, V));

	// If we randomly selected to sample our diffuse lobe...
	if (chooseDiffuse)
	{
		// Shoot a randomly selected cosine-sampled diffuse ray.
		float3 L = getCosHemisphereSample(rndSeed, N);
		float3 bounceColor = shootIndirectRay(hit, L, gMinT, 0, rndSeed, rayDepth);

		// Check to make sure our randomly selected, normal mapped diffuse ray didn't go below the surface.
		if (dot(noNormalN, L) <= 0.0f) bounceColor = float3(0, 0, 0);

		// Accumulate the color: (NdotL * incomingLight * dif / pi) 
		// Probability of sampling:  (NdotL / pi) * probDiffuse
		return bounceColor * dif / probDiffuse;
	}
	// Otherwise we randomly selected to sample our GGX lobe
	else
	{
		// Randomly sample the NDF to get a microfacet in our BRDF to reflect off of
		float3 H = getGGXMicrofacet(rndSeed, rough, N);

		// Compute the outgoing direction based on this (perfectly reflective) microfacet
		float3 L = normalize(2.f * dot(V, H) * H - V);

		// Compute our color by tracing a ray in this direction
		float3 bounceColor = shootIndirectRay(hit, L, gMinT, 0, rndSeed, rayDepth);

		// Check to make sure our randomly selected, normal mapped diffuse ray didn't go below the surface.
		if (dot(noNormalN, L) <= 0.0f) bounceColor = float3(0, 0, 0);

		// Compute some dot products needed for shading
		float  NdotL = saturate(dot(N, L));
		float  NdotH = saturate(dot(N, H));
		float  LdotH = saturate(dot(L, H));

		// Evaluate our BRDF using a microfacet BRDF model
		float  D = ggxNormalDistribution(NdotH, rough);          // The GGX normal distribution
		float  G = ggxSchlickMaskingTerm(NdotL, NdotV, rough);   // Use Schlick's masking term approx
		float3 F = schlickFresnel(spec, LdotH);                  // Use Schlick's approx to Fresnel
		float3 ggxTerm = D * G * F / (4 * NdotL * NdotV);        // The Cook-Torrance microfacet BRDF

		// What's the probability of sampling vector H from getGGXMicrofacet()?
		float  ggxProb = D * NdotH / (4 * LdotH);

		// Accumulate the color:  ggx-BRDF * incomingLight * NdotL / probability-of-sampling
		//    -> Should really simplify the math above.
		return NdotL * bounceColor * ggxTerm / (ggxProb * (1.0f - probDiffuse));
	}
}

[shader("closesthit")]
void IndirectClosestHit(inout IndirectRayPayload rayData, BuiltInTriangleIntersectionAttributes attribs)
{
	// Run a helper functions to extract Falcor scene data for shading
	ShadingData shadeData = getHitShadingData( attribs, WorldRayOrigin() );

    // Add emissive color
    rayData.color = gEmitMult * shadeData.emissive.rgb;

	// Do direct illumination at this hit location
    if (gDoDirectGI)
    {
        rayData.color += ggxDirect(rayData.rndSeed, shadeData.posW, shadeData.N, shadeData.V,
            shadeData.diffuse, shadeData.specular, shadeData.roughness);
    }

	// Do indirect illumination at this hit location (if we haven't traversed too far)
	if (rayData.rayDepth < gMaxDepth)
	{
		// Use the same normal for the normal-mapped and non-normal mapped vectors... This means we could get light
		//     leaks at secondary surfaces with normal maps due to indirect rays going below the surface.  This
		//     isn't a huge issue, but this is a (TODO: fix)
		rayData.color += ggxIndirect(rayData.rndSeed, shadeData.posW, shadeData.N, shadeData.N, shadeData.V,
			shadeData.diffuse, shadeData.specular, shadeData.roughness, rayData.rayDepth);
	}
}


struct DirectLightingIntegrator {
	float3 Li(RayDesc ray, uint randSeed, uint2 pixelIndex, float3 hit, float3 N, float3 V, float3 dif, float3 spec, float rough) {
        int lightToSample = min(int(nextRand(randSeed) * gLightsCount), gLightsCount - 1);

        float distToLight;
        float3 lightIntensity;
        float3 L;
        getLightData(lightToSample, hit, L, lightIntensity, distToLight);

        float NdotL = saturate(dot(N, L));

        float shadowMult = float(gLightsCount) * shootShadowRay(hit, L, gMinT, distToLight);

        float3 H = normalize(V + L);
        float NdotH = saturate(dot(N, H));
        float LdotH = saturate(dot(L, H));
        float NdotV = saturate(dot(N, V));

        float  D = ggxNormalDistribution(NdotH, rough);
        float  G = ggxSchlickMaskingTerm(NdotL, NdotV, rough);
        float3 F = schlickFresnel(spec, LdotH);

        float3 ggxTerm = D*G*F / (4 * NdotV /* * NdotL */);

        return shadowMult * lightIntensity * ( /* NdotL * */ ggxTerm + NdotL * dif / M_PI);
	}
};