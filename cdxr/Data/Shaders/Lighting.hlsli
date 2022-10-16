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

float3 sampleLight(int lightIndex, float3 worldPosition, float3 worldNormal, bool doShadows, float minT) {
    float distanceToLight;
    float3 lightIntensity;
    float3 directionToLight;
    getLightData(lightIndex, worldPosition, directionToLight, lightIntensity, distanceToLight);

    // Compute lambertian factor.
    float LdotN = saturate(dot(directionToLight, worldNormal));

    float shadowFactor = float(gLightsCount);
    if (doShadows) {
        shadowFactor *= shootShadowRay(worldPosition, directionToLight, minT, distanceToLight);
    }

    return lightIntensity * LdotN * shadowFactor / M_PI;
}