cbuffer PerFrameCB {
    // Number of frames accumulated in gLastFrame.
    uint gNumFramesAccum;
}

// The accumulation texture.
Texture2D<float4> gLastFrame;

// The new frame, as produced by the previous pass, the RayTracedAmbientOcclusionPass.
Texture2D<float4> gCurFrame;

float4 main(float2 texC : TEXCOORD, float4 pos : SV_POSITION) : SV_Target0 {
    uint2 pixelPosition = (uint2) pos.xy;
    float4 curColor = gCurFrame[pixelPosition];
    float4 prevColor = gLastFrame[pixelPosition];

    // A weighted average of the accumulated pixel color and the new frame's.
    // The new frame is supplied by the previous pass, the RayTracedAmbientOcclusionPass.
    // The weight of the accumulated color is the number of accumulated frames, whereas
    // the weight of the new frame's color is just 1. At the time of invocation.
    return (gNumFramesAccum*prevColor + curColor) / (gNumFramesAccum + 1);
}