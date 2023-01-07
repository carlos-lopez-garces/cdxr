struct GGXNormalDistribution {
    // From http://cwyman.org/code/dxrTutors/tutors/Tutor14/tutorial14.md.html.
    float D(float3 N, float3 H, float roughness) {
        float NdotH = saturate(dot(N, H));
        float a2 = roughness * roughness;
        float d = ((NdotH * a2 - NdotH) * NdotH + 1);
        return a2 / (d * d * M_PI);
    }

    // From https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf.
    float G(float3 N float3 L, float3 V, float roughness) {
        float NdotL = saturate(dot(N, L));
        float NdotV = saturate(dot(N, V));
        float k = roughness*roughness / 2;
        float g_v = NdotV / (NdotV*(1 - k) + k);
        float g_l = NdotL / (NdotL*(1 - k) + k);
        return g_v * g_l;
    }
};