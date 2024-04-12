#ifndef UNITY_POSTFX_DEPTH_OF_FIELD
#define UNITY_POSTFX_DEPTH_OF_FIELD

#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Colors.hlsl"
#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Builtins/DiskKernels.hlsl"

TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
float4 _MainTex_TexelSize;

TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
TEXTURE2D_SAMPLER2D(_CameraMotionVectorsTexture, sampler_CameraMotionVectorsTexture);

TEXTURE2D_SAMPLER2D(_CoCTex, sampler_CoCTex);
TEXTURE2D_SAMPLER2D(_MaxCoCTex, sampler_MaxCoCTex);

TEXTURE2D_SAMPLER2D(_DepthOfFieldTex, sampler_DepthOfFieldTex);
float4 _DepthOfFieldTex_TexelSize;

// Camera parameters
float _Distance;
float _LensCoeff;  // f^2 / (N * (S1 - f) * film_width * 2)
half4 _CoCKernelLimitsA;
half4 _CoCKernelLimitsB;
float4 _MaxCoCTexUvScale; // (kc)rename + move more variables to half
float _CoCRingCount;
float4 _CoCScreen;
float _CoCTileXCount;
float _CoCTileYCount;
float _CoCTilePixelWidth;
float _CoCTilePixelHeight;
float _MaxCoC;
float _RcpMaxCoC;
float _RcpAspect;
half3 _TaaParams; // Jitter.x, Jitter.y, Blending

// CoC calculation
half4 FragCoC(VaryingsDefault i) : SV_Target
{
    float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoordStereo));
    half coc = (depth - _Distance) * _LensCoeff / max(depth, 1e-4);
    return saturate(coc * 0.5 * _RcpMaxCoC + 0.5);
}

// Temporal filter
half4 FragTempFilter(VaryingsDefault i) : SV_Target
{
    float3 uvOffs = _MainTex_TexelSize.xyy * float3(1.0, 1.0, 0.0);

#if UNITY_GATHER_SUPPORTED

    half4 cocTL = GATHER_RED_TEXTURE2D(_CoCTex, sampler_CoCTex, UnityStereoTransformScreenSpaceTex(i.texcoord - uvOffs.xy * 0.5)); // top-left
    half4 cocBR = GATHER_RED_TEXTURE2D(_CoCTex, sampler_CoCTex, UnityStereoTransformScreenSpaceTex(i.texcoord + uvOffs.xy * 0.5)); // bottom-right
    half coc1 = cocTL.x; // top
    half coc2 = cocTL.z; // left
    half coc3 = cocBR.x; // bottom
    half coc4 = cocBR.z; // right

#else

    half coc1 = SAMPLE_TEXTURE2D(_CoCTex, sampler_CoCTex, UnityStereoTransformScreenSpaceTex(i.texcoord - uvOffs.xz)).r; // top
    half coc2 = SAMPLE_TEXTURE2D(_CoCTex, sampler_CoCTex, UnityStereoTransformScreenSpaceTex(i.texcoord - uvOffs.zy)).r; // left
    half coc3 = SAMPLE_TEXTURE2D(_CoCTex, sampler_CoCTex, UnityStereoTransformScreenSpaceTex(i.texcoord + uvOffs.zy)).r; // bottom
    half coc4 = SAMPLE_TEXTURE2D(_CoCTex, sampler_CoCTex, UnityStereoTransformScreenSpaceTex(i.texcoord + uvOffs.xz)).r; // right

#endif

    // Dejittered center sample.
    half coc0 = SAMPLE_TEXTURE2D(_CoCTex, sampler_CoCTex, UnityStereoTransformScreenSpaceTex(i.texcoord - _TaaParams.xy)).r;

    // CoC dilation: determine the closest point in the four neighbors
    float3 closest = float3(0.0, 0.0, coc0);
    closest = coc1 < closest.z ? float3(-uvOffs.xz, coc1) : closest;
    closest = coc2 < closest.z ? float3(-uvOffs.zy, coc2) : closest;
    closest = coc3 < closest.z ? float3( uvOffs.zy, coc3) : closest;
    closest = coc4 < closest.z ? float3( uvOffs.xz, coc4) : closest;

    // Sample the history buffer with the motion vector at the closest point
    float2 motion = SAMPLE_TEXTURE2D(_CameraMotionVectorsTexture, sampler_CameraMotionVectorsTexture, UnityStereoTransformScreenSpaceTex(i.texcoord + closest.xy)).xy;
    half cocHis = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(i.texcoord - motion)).r;

    // Neighborhood clamping
    half cocMin = closest.z;
    half cocMax = Max3(Max3(coc0, coc1, coc2), coc3, coc4);
    cocHis = clamp(cocHis, cocMin, cocMax);

    // Blend with the history
    return lerp(coc0, cocHis, _TaaParams.z);
}

// Prefilter: downsampling and premultiplying
half4 FragPrefilter(VaryingsDefault i) : SV_Target
{
#if UNITY_GATHER_SUPPORTED

    // Sample source colors
    half4 c_r = GATHER_RED_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);
    half4 c_g = GATHER_GREEN_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);
    half4 c_b = GATHER_BLUE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);

    half3 c0 = half3(c_r.x, c_g.x, c_b.x);
    half3 c1 = half3(c_r.y, c_g.y, c_b.y);
    half3 c2 = half3(c_r.z, c_g.z, c_b.z);
    half3 c3 = half3(c_r.w, c_g.w, c_b.w);

    // Sample CoCs
    half4 cocs = GATHER_TEXTURE2D(_CoCTex, sampler_CoCTex, i.texcoordStereo) * 2.0 - 1.0;
    half coc0 = cocs.x;
    half coc1 = cocs.y;
    half coc2 = cocs.z;
    half coc3 = cocs.w;

#else

    float3 duv = _MainTex_TexelSize.xyx * float3(0.5, 0.5, -0.5);
    float2 uv0 = UnityStereoTransformScreenSpaceTex(i.texcoord - duv.xy);
    float2 uv1 = UnityStereoTransformScreenSpaceTex(i.texcoord - duv.zy);
    float2 uv2 = UnityStereoTransformScreenSpaceTex(i.texcoord + duv.zy);
    float2 uv3 = UnityStereoTransformScreenSpaceTex(i.texcoord + duv.xy);

    // Sample source colors
    half3 c0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv0).rgb;
    half3 c1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv1).rgb;
    half3 c2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv2).rgb;
    half3 c3 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv3).rgb;

    // Sample CoCs
    half coc0 = SAMPLE_TEXTURE2D(_CoCTex, sampler_CoCTex, uv0).r * 2.0 - 1.0;
    half coc1 = SAMPLE_TEXTURE2D(_CoCTex, sampler_CoCTex, uv1).r * 2.0 - 1.0;
    half coc2 = SAMPLE_TEXTURE2D(_CoCTex, sampler_CoCTex, uv2).r * 2.0 - 1.0;
    half coc3 = SAMPLE_TEXTURE2D(_CoCTex, sampler_CoCTex, uv3).r * 2.0 - 1.0;

#endif

    // Apply CoC and luma weights to reduce bleeding and flickering
    float w0 = abs(coc0) / (Max3(c0.r, c0.g, c0.b) + 1.0);
    float w1 = abs(coc1) / (Max3(c1.r, c1.g, c1.b) + 1.0);
    float w2 = abs(coc2) / (Max3(c2.r, c2.g, c2.b) + 1.0);
    float w3 = abs(coc3) / (Max3(c3.r, c3.g, c3.b) + 1.0);

    // Weighted average of the color samples
    half3 avg = c0 * w0 + c1 * w1 + c2 * w2 + c3 * w3;
    avg /= max(w0 + w1 + w2 + w3, 1e-4);

    // Select the largest CoC value
    half coc_min = min(coc0, Min3(coc1, coc2, coc3));
    half coc_max = max(coc0, Max3(coc1, coc2, coc3));
    half coc = (-coc_min > coc_max ? coc_min : coc_max) * _MaxCoC;

    // Premultiply CoC again
    avg *= smoothstep(0, _MainTex_TexelSize.y * 2, abs(coc));

#if defined(UNITY_COLORSPACE_GAMMA)
    avg = SRGBToLinear(avg);
#endif

    return half4(avg, coc);
}

VaryingsDefault VertDownsampleCoC(AttributesDefault v)
{
    VaryingsDefault o;
    o.vertex = float4(v.vertex.xy, 0.0, 1.0);
    o.texcoord = TransformTriangleVertexToUV(v.vertex.xy);
#if defined(INITIAL_COC)
    o.texcoord *= _MaxCoCTexUvScale.xy;
#endif

#if UNITY_UV_STARTS_AT_TOP
    o.texcoord = o.texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
#endif

    o.texcoordStereo = TransformStereoScreenSpaceTex(o.texcoord, 1.0);

    return o;
}

half4 FragDownsampleCoC(VaryingsDefault i) : SV_Target
{
    // TODO implement gather version

    float3 duv = _MainTex_TexelSize.xyx * float3(0.5, 0.5, -0.5);
    float2 uv0 = UnityStereoTransformScreenSpaceTex(i.texcoord - duv.xy);
    float2 uv1 = UnityStereoTransformScreenSpaceTex(i.texcoord - duv.zy);
    float2 uv2 = UnityStereoTransformScreenSpaceTex(i.texcoord + duv.zy);
    float2 uv3 = UnityStereoTransformScreenSpaceTex(i.texcoord + duv.xy);

    // Sample CoCs
    half4 cocs;
    cocs.x = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv0).r;
    cocs.y = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv1).r;
    cocs.z = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv2).r;
    cocs.w = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv3).r;

#if defined(INITIAL_COC)
    // Storing the absolute normalized CoC is enough.
    cocs = cocs * 2.0 - 1.0;
#endif
    cocs = abs(cocs);

    half maxCoC = max(cocs.x, Max3(cocs.y, cocs.z, cocs.w));
    return half4(maxCoC, 0.0, 0.0, 0.0);
}

half4 FragExtendCoC(VaryingsDefault i) : SV_Target
{
    float tx = _MainTex_TexelSize.x;
    float ty = _MainTex_TexelSize.y;

    float2 uv0 = UnityStereoTransformScreenSpaceTex(i.texcoord);
    float2 uv1 = UnityStereoTransformScreenSpaceTex(i.texcoord + float2( tx,  0));
    float2 uv2 = UnityStereoTransformScreenSpaceTex(i.texcoord + float2( tx, ty));
    float2 uv3 = UnityStereoTransformScreenSpaceTex(i.texcoord + float2(  0, ty));
    float2 uv4 = UnityStereoTransformScreenSpaceTex(i.texcoord + float2(-tx, ty));
    float2 uv5 = UnityStereoTransformScreenSpaceTex(i.texcoord + float2(-tx,  0));
    float2 uv6 = UnityStereoTransformScreenSpaceTex(i.texcoord + float2(-tx,-ty));
    float2 uv7 = UnityStereoTransformScreenSpaceTex(i.texcoord + float2(  0,-ty));
    float2 uv8 = UnityStereoTransformScreenSpaceTex(i.texcoord + float2( tx,-ty));

    half coc0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv0).r;
    half coc1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv1).r;
    half coc2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv2).r;
    half coc3 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv3).r;
    half coc4 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv4).r;
    half coc5 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv5).r;
    half coc6 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv6).r;
    half coc7 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv7).r;
    half coc8 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv8).r;

    half maxCoC = Max3(Max3(coc0, coc1, coc2), Max3(coc3, coc4, coc5), Max3(coc6, coc7, coc8));
    return half4(maxCoC, 0.0, 0.0, 0.0);
}


// Bokeh filter with disk-shaped kernels
half4 FragBlur(VaryingsDefault i) : SV_Target
{
    const half margin = _MainTex_TexelSize.y * 2;

    half4 samp0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);

    half4 bgAcc = 0.0; // Background: far field bokeh
    half4 fgAcc = 0.0; // Foreground: near field bokeh

#if defined(KERNEL_UNIFIED)
    int sampleCount = kDiskAllKernelSizes[KERNEL_UNIFIED];
#else
    int sampleCount = kSampleCount;
#endif

    UNITY_LOOP
    for (int si = 0; si < sampleCount; si++)
    {
#if defined(KERNEL_UNIFIED)
        float2 disp = kDiskAllKernels[si] * (_MaxCoC * (12.0 / 8.0));
#else
        float2 disp = kDiskKernel[si] * _MaxCoC;
#endif
        float dist = length(disp);

        float2 duv = float2(disp.x * _RcpAspect, disp.y);
        half4 samp = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(i.texcoord + duv));

        // BG: Compare CoC of the current sample and the center sample
        // and select smaller one.
        half bgCoC = max(min(samp0.a, samp.a), 0.0);

        // Compare the CoC to the sample distance.
        // Add a small margin to smooth out.
        half bgWeight = saturate((bgCoC - dist + margin) / margin);
        half fgWeight = saturate((-samp.a - dist + margin) / margin);

        // Cut influence from focused areas because they're darkened by CoC
        // premultiplying. This is only needed for near field.
        fgWeight *= step(_MainTex_TexelSize.y, -samp.a);

        // Accumulation
        bgAcc += half4(samp.rgb, 1.0) * bgWeight;
        fgAcc += half4(samp.rgb, 1.0) * fgWeight;
    }

    // Get the weighted average.
    bgAcc.rgb /= bgAcc.a + (bgAcc.a == 0.0); // zero-div guard
    fgAcc.rgb /= fgAcc.a + (fgAcc.a == 0.0);

    // BG: Calculate the alpha value only based on the center CoC.
    // This is a rather aggressive approximation but provides stable results.
    bgAcc.a = smoothstep(_MainTex_TexelSize.y, _MainTex_TexelSize.y * 2.0, samp0.a);

    // FG: Normalize the total of the weights.
    fgAcc.a *= PI / sampleCount;

    // Alpha premultiplying
    half alpha = saturate(fgAcc.a);
    half3 rgb = lerp(bgAcc.rgb, fgAcc.rgb, alpha);

    return half4(rgb, alpha);
}

// Bokeh filter with disk-shaped kernels
half4 FragBlurDynamic(VaryingsDefault i) : SV_Target
{
    half4 samp0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);
    // normalized value in range [0, 1]
    half maxCoC = SAMPLE_TEXTURE2D(_MaxCoCTex, sampler_MaxCoCTex, i.texcoordStereo * _MaxCoCTexUvScale.zw).r;

    int sampleCount;

    UNITY_BRANCH if (maxCoC < _CoCKernelLimitsA[0])
        sampleCount = kDiskAllKernelSizes[0];
    // margin adjustment later in the shader code artifically expand bokeh by 4px in fullscreen units (1 extra ring), we cannot have small bokeh as a result!
    else UNITY_BRANCH if (maxCoC < _CoCKernelLimitsA[1])
        sampleCount = kDiskAllKernelSizes[1+1];
    else UNITY_BRANCH if (maxCoC < _CoCKernelLimitsA[2])
        sampleCount = kDiskAllKernelSizes[2+1];
    else UNITY_BRANCH if (maxCoC < _CoCKernelLimitsA[3])
        sampleCount = kDiskAllKernelSizes[3+1];
    else
        sampleCount = kDiskAllKernelSizes[4];

    const half margin = _MainTex_TexelSize.y * 2;

    half4 bgAcc = 0.0; // Background: far field bokeh
    half4 fgAcc = 0.0; // Foreground: near field bokeh

    UNITY_LOOP
    for (int si = 0; si < sampleCount; si++)
    {
        float2 disp = kDiskAllKernels[si] * (_MaxCoC * (12.0 / 8.0));

        float dist = length(disp);

        float2 duv = float2(disp.x * _RcpAspect, disp.y);
        half4 samp = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(i.texcoord + duv));

        // BG: Compare CoC of the current sample and the center sample
        // and select smaller one.
        half bgCoC = max(min(samp0.a, samp.a), 0.0);

        // Compare the CoC to the sample distance.
        // Add a small margin to smooth out.
        half bgWeight = saturate((bgCoC - dist + margin) / margin);
        half fgWeight = saturate((-samp.a - dist + margin) / margin);

        // Cut influence from focused areas because they're darkened by CoC
        // premultiplying. This is only needed for near field.
        fgWeight *= step(_MainTex_TexelSize.y, -samp.a);

        // Accumulation
        bgAcc += half4(samp.rgb, 1.0) * bgWeight;
        fgAcc += half4(samp.rgb, 1.0) * fgWeight;
    }

    // Get the weighted average.
    bgAcc.rgb /= bgAcc.a + (bgAcc.a == 0.0); // zero-div guard
    fgAcc.rgb /= fgAcc.a + (fgAcc.a == 0.0);

    // BG: Calculate the alpha value only based on the center CoC.
    // This is a rather aggressive approximation but provides stable results.
    bgAcc.a = smoothstep(_MainTex_TexelSize.y, _MainTex_TexelSize.y * 2.0, samp0.a);

    // FG: Normalize the total of the weights.
    fgAcc.a *= PI / sampleCount;

    // Alpha premultiplying
    half alpha = saturate(fgAcc.a);
    half3 rgb = lerp(bgAcc.rgb, fgAcc.rgb, alpha);

    return half4(rgb, alpha);
}

struct Attributes
{
    uint vertexID   : SV_VertexID;
    uint instanceID : SV_InstanceID;
};

uint2 UnpackTileID(uint tileID)
{
    return uint2(tileID & 0xFFFF, (tileID >> 16) & 0xFFFF);
}

// 0 - 0,1
// 1 - 0,0
// 2 - 1,0
// 3 - 1,1
float4 GetQuadVertexPosition(uint vertexID, float z = UNITY_NEAR_CLIP_VALUE)
{
    uint topBit = vertexID >> 1;
    uint botBit = (vertexID & 1);
    float x = topBit;
    float y = 1 - (topBit + botBit) & 1; // produces 1 for indices 0,3 and 0 for 1,2
    float4 pos = float4(x, y, z, 1.0);
    return pos;
}

VaryingsDefault VertexTiling(Attributes input)
{
    uint2 tileCoord = uint2(input.instanceID % (uint)_CoCTileXCount, input.instanceID / (uint)_CoCTileXCount); // (kc) stereo mode?
    // normalized value in range [0, 1]
    half maxCoC = LOAD_TEXTURE2D(_MaxCoCTex, _MaxCoCTex_TexelSize, tileCoord).x;

    bool shouldDiscard;

    UNITY_BRANCH if (maxCoC < _CoCKernelLimitsA[0])
        shouldDiscard = _CoCRingCount != 0;
    // margin adjustment later in the shader code artifically expand bokeh by 4px in fullscreen units (1 extra ring), we cannot have small bokeh as a result!
    else UNITY_BRANCH if (maxCoC < _CoCKernelLimitsA[1])
        shouldDiscard = _CoCRingCount != 1+1;
    else UNITY_BRANCH if (maxCoC < _CoCKernelLimitsA[2])
        shouldDiscard = _CoCRingCount != 2+1;
    else UNITY_BRANCH if (maxCoC < _CoCKernelLimitsA[3])
        shouldDiscard = _CoCRingCount != 3+1;
    else
        shouldDiscard = _CoCRingCount != 4;

    VaryingsDefault output;

    [branch] if (shouldDiscard)
    {
        output.vertex = float4(-2, -2, -2, 1);
        output.texcoord = 0.0.xx;
        output.texcoordStereo = 0.0.xx;
#if STEREO_INSTANCING_ENABLED
        output.stereoTargetEyeIndex = 0;
#endif
        return output;
    }

    // This handles both "real quad" and "2 triangles" cases: remaps {0, 1, 2, 3, 4, 5} into {0, 1, 2, 3, 0, 2}.
    uint quadIndex = (input.vertexID & 0x03) + (input.vertexID >> 2) * (input.vertexID & 0x01);
    float2 pp = GetQuadVertexPosition(quadIndex).xy;
    uint2 pixelCoord = tileCoord * uint2(_CoCTilePixelWidth, _CoCTilePixelHeight);
    pixelCoord += uint2(pp.xy * uint2(_CoCTilePixelWidth, _CoCTilePixelHeight));
    pixelCoord.y = _CoCScreen.y - pixelCoord.y;
    float2 clipCoord = (pixelCoord * _CoCScreen.zw) * 2.0 - 1.0;

    output.vertex = float4(clipCoord, 0, 1);
    output.texcoord = clipCoord * 0.5 + 0.5;
    #if UNITY_UV_STARTS_AT_TOP
    output.texcoord = output.texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
    #endif
    output.texcoordStereo = TransformStereoScreenSpaceTex(output.texcoord, 1.0);

    return output;
}

// Postfilter blur
half4 FragPostBlur(VaryingsDefault i) : SV_Target
{
    // 9 tap tent filter with 4 bilinear samples
    const float4 duv = _MainTex_TexelSize.xyxy * float4(0.5, 0.5, -0.5, 0);
    half4 acc;
    acc  = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(i.texcoord - duv.xy));
    acc += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(i.texcoord - duv.zy));
    acc += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(i.texcoord + duv.zy));
    acc += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(i.texcoord + duv.xy));
    return acc / 4.0;
}

// Combine with source
half4 FragCombine(VaryingsDefault i) : SV_Target
{
    half4 dof = SAMPLE_TEXTURE2D(_DepthOfFieldTex, sampler_DepthOfFieldTex, i.texcoordStereo);
    half coc = SAMPLE_TEXTURE2D(_CoCTex, sampler_CoCTex, i.texcoordStereo).r;
    coc = (coc - 0.5) * 2.0 * _MaxCoC;

    // Convert CoC to far field alpha value.
    float ffa = smoothstep(_MainTex_TexelSize.y * 2.0, _MainTex_TexelSize.y * 4.0, coc);

    half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);

#if defined(UNITY_COLORSPACE_GAMMA)
    color = SRGBToLinear(color);
#endif

    half alpha = Max3(dof.r, dof.g, dof.b);

    // lerp(lerp(color, dof, ffa), dof, dof.a)
    color = lerp(color, float4(dof.rgb, alpha), ffa + dof.a - ffa * dof.a);

#if defined(UNITY_COLORSPACE_GAMMA)
    color = LinearToSRGB(color);
#endif

    return color;
}

// Debug overlay
half4 FragDebugOverlay(VaryingsDefault i) : SV_Target
{
    half3 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo).rgb;

    // Calculate the radiuses of CoC.
    half4 src = SAMPLE_TEXTURE2D(_DepthOfFieldTex, sampler_DepthOfFieldTex, i.texcoordStereo);
    float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoordStereo));
    float coc = (depth - _Distance) * _LensCoeff / depth;
    coc *= 80;

    // Visualize CoC (white -> red -> gray)
    half3 rgb = lerp(half3(1.0, 0.0, 0.0), half3(1.0, 1.0, 1.0), saturate(-coc));
    rgb = lerp(rgb, half3(0.4, 0.4, 0.4), saturate(coc));

    // Black and white image overlay
    rgb *= Luminance(color) + 0.5;

    // Gamma correction
#if !UNITY_COLORSPACE_GAMMA
    rgb = SRGBToLinear(rgb);
#endif

    return half4(rgb, 1.0);
}

#endif // UNITY_POSTFX_DEPTH_OF_FIELD
