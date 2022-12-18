bool IsDeltaLight(LightData light) {
    return light.type == LightPoint || light.type == LightDirectional;
}