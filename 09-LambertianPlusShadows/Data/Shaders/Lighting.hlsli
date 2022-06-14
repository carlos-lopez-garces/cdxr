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