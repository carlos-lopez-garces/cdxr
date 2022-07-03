void getLightData(in int index, in float3 hitPos, out float3 directionToLight, out float3 lightIntensity, out float distanceToLight) {
	LightSample ls;

	if (gLights[index].type == LightDirectional) {
        ls = evalDirectionalLight(gLights[index], hitPos);
    } else {
        ls = evalPointLight(gLights[index], hitPos);
    }

	directionToLight = normalize(ls.L);
	lightIntensity = ls.diffuse;
	distanceToLight = length(ls.posW - hitPos);
}

float3 sampleLight(int lightIndex, float4 worldPosition, float4 worldNormal, float pdf, bool shadows, float minT) {
    float distanceToLight;
    float3 lightIntensity;
    float3 directionToLight;
    getLightData(lightIndex, worldPosition.xyz, directionToLight, lightIntensity, distanceToLight);

    // Compute lambertian factor.
    float LdotN = saturate(dot(directionToLight, worldNormal.xyz));

    // Dividing by the probability of choosing this light is crucial!
    float shadowFactor = 1.0f / pdf;
    if (shadows) {
        shadowFactor = shootShadowRay(worldPosition.xyz, directionToLight, minT, distanceToLight) / pdf;
    }

    return lightIntensity * LdotN * shadowFactor;
}