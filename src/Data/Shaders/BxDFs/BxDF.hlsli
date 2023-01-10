#include "LambertianBRDF.hlsli"
#include "SpecularBRDF.hlsli"
#include "TorranceSparrowMicrofacetBRDF.hlsli"

#define BXDF_NONE 0
#define BRDF_DIFFUSE 1
#define BRDF_SPECULAR 2

// Let P = getBRDFProbability(...). Then P is the probability of a specular bounce off of this
// material and 1 - P of a diffuse bounce.
// From github.com/boksajak/referencePT.
float getBRDFProbability(MaterialData material, float3 V, float3 shadingNormal) {
    // When using ShadingModelMetalRough. See Falcor3.1\Framework\Source\Graphics\Material\Material.h.
    float3 baseColor = float3(material.baseColor.r, material.baseColor.g, material.baseColor.b);
    float metalness = material.specular.g;

    float specularF0 = luminance(baseColorToSpecularF0(baseColor, metalness));
    float diffuseReflectance = luminance(baseColorToDiffuseReflectance(baseColor, metalness));

    float fresnel = saturate(luminance(evaluateFresnel(
        specularF0, 
        shadowedF90(specularF0),
        max(0.0f, dot(V, shadingNormal))
    )));

    float specular = fresnel;
    float diffuse = diffuseReflectance * (1.0f - fresnel);
    float p = (specular / max(0.0001f, (specular + diffuse)));
    return clamp(p, 0.1f, 0.9f);
}

// From http://cwyman.org/code/dxrTutors/tutors/Tutor14/tutorial14.md.html.
float probabilityToSampleDiffuse(float3 difColor, float3 specColor) {
	float lumDiffuse = max(0.01f, luminance(difColor.rgb));
	float lumSpecular = max(0.01f, luminance(specColor.rgb));
	return lumDiffuse / (lumDiffuse + lumSpecular);
}