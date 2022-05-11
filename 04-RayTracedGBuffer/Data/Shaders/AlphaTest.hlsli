// attributes are the attributes of the current hit/intersection.
bool alphaTestFails(BuiltInTriangleIntersectionAttributes attributes) {
    // PrimitiveIndex() is an object introspection intrinsic that returns
    // the identifier of the current primitive.
    VertexOut vsOut = getVertexAttributes(PrimitiveIndex(), attributes);

    // ExplicitLodTextureSampler is a Falcor type with a sampleTexture()
    // method where the LOD or mipmap level to sample can be specified. 
    ExplicitLodTextureSampler lodSampler = { 0 };

    float4 baseColor = sampleTexture(
        gMaterial.resources.baseColor,
        gMaterial.resources.samplerState,
        vsOut.texC,
        gMaterial.baseColor,
        EXTRACT_DIFFUSE_TYPE(gMaterial.flags),
        lodSampler
    );

    // The alpha channel of the diffuse color is the opacity of the material.
    return (baseColor.a < gMaterial.alphaThreshold);
}