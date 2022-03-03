#ifndef CAPSULE_SHADOWS_GLOBALS_DEF
#define CAPSULE_SHADOWS_GLOBALS_DEF

#include "Packages/com.unity.render-pipelines.core/Runtime/Lighting/CapsuleShadows/CapsuleShadowsCommon.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/CapsuleShadows/CapsuleOccluderData.cs.hlsl"

#define _CapsuleDirectShadowCount           (_CapsuleDirectShadowCountAndFlags & CAPSULESHADOWFLAGS_COUNT_MASK)
#define _CapsuleDirectShadowMethod          ((_CapsuleDirectShadowCountAndFlags & CAPSULESHADOWFLAGS_METHOD_MASK) >> CAPSULESHADOWFLAGS_METHOD_SHIFT)
#define _CapsuleFadeDirectSelfShadow        ((_CapsuleDirectShadowCountAndFlags & CAPSULESHADOWFLAGS_FADE_SELF_SHADOW_BIT) != 0)

#define _CapsuleShadowInLightLoop           ((_CapsuleDirectShadowCountAndFlags & CAPSULESHADOWFLAGS_LIGHT_LOOP_BIT) != 0)
#define _CapsuleShadowIsHalfRes             ((_CapsuleDirectShadowCountAndFlags & CAPSULESHADOWFLAGS_HALF_RES_BIT) != 0)
#define _CapsuleSplitDepthRange             ((_CapsuleDirectShadowCountAndFlags & CAPSULESHADOWFLAGS_SPLIT_DEPTH_RANGE_BIT) != 0)
#define _CapsuleDirectShadowsEnabled        ((_CapsuleDirectShadowCountAndFlags & CAPSULESHADOWFLAGS_DIRECT_ENABLED_BIT) != 0)
#define _CapsuleIndirectShadowsEnabled      ((_CapsuleDirectShadowCountAndFlags & CAPSULESHADOWFLAGS_INDIRECT_ENABLED_BIT) != 0)
#define _CapsuleShadowsNeedsTileCheck       ((_CapsuleDirectShadowCountAndFlags & CAPSULESHADOWFLAGS_NEEDS_TILE_CHECK_BIT) != 0)

#define _CapsuleIndirectShadowCount         (_CapsuleIndirectShadowCountAndExtra & CAPSULESHADOWFLAGS_COUNT_MASK)
#define _CapsuleIndirectShadowMethod        ((_CapsuleIndirectShadowCountAndExtra & CAPSULESHADOWFLAGS_METHOD_MASK) >> CAPSULESHADOWFLAGS_METHOD_SHIFT)
#define _CapsuleIndirectShadowExtra         ((_CapsuleIndirectShadowCountAndExtra & CAPSULESHADOWFLAGS_EXTRA_MASK) >> CAPSULESHADOWFLAGS_EXTRA_SHIFT)

#define _FirstDepthMipOffset                uint2(_FirstDepthMipOffsetX, _FirstDepthMipOffsetY)
#define _CapsuleRenderSizeInTiles           uint2(_CapsuleRenderSizeInTilesX, _CapsuleRenderSizeInTilesY)
#define _CapsuleUpscaledSizeInTiles         uint2(_CapsuleUpscaledSizeInTilesX, _CapsuleUpscaledSizeInTilesY)

uint GetCapsuleDirectOcclusionFlags()
{
#if 0
    return CAPSULEOCCLUSIONFLAGS_LIGHT_AXIS_SCALE | CAPSULEOCCLUSIONFLAGS_FADE_SELF_SHADOW;
#else
    uint flags = 0;
    switch (_CapsuleDirectShadowMethod) {
    case CAPSULESHADOWMETHOD_ELLIPSOID:
        flags |= CAPSULEOCCLUSIONFLAGS_CAPSULE_AXIS_SCALE;
        break;
    case CAPSULESHADOWMETHOD_FLATTEN_THEN_CLOSEST_SPHERE:
        flags |= CAPSULEOCCLUSIONFLAGS_LIGHT_AXIS_SCALE;
        break;
    }
    if (_CapsuleFadeDirectSelfShadow) {
        flags |= CAPSULEOCCLUSIONFLAGS_FADE_SELF_SHADOW;
    }
    return flags;
#endif
}

uint GetCapsuleAmbientOcclusionFlags()
{
#if 0
    return 0;
#else
    uint flags = 0;
    if (_CapsuleIndirectShadowExtra == CAPSULEAMBIENTOCCLUSIONMETHOD_LINE_AND_CLOSEST_SPHERE)
        flags |= CAPSULEAMBIENTOCCLUSIONFLAGS_INCLUDE_AXIS;
    return flags;
#endif
}

uint GetCapsuleIndirectOcclusionFlags()
{
    // hardcoded (probably cheapest) shadow function
    return CAPSULEOCCLUSIONFLAGS_CAPSULE_AXIS_SCALE | CAPSULEOCCLUSIONFLAGS_FADE_SELF_SHADOW | CAPSULEOCCLUSIONFLAGS_FADE_AT_HORIZON;
}

struct CapsuleShadowsUpscaleTile
{
    uint coord; // half resolution tile coordinate [31:30]=viewIndex, [29:15]=y, [14:0]=x
    uint bits;  // one bit per caster
};

CapsuleShadowsUpscaleTile makeCapsuleShadowsUpscaleTile(uint2 coord, uint bits)
{
    uint viewIndex = unity_StereoEyeIndex;

    CapsuleShadowsUpscaleTile tile;
    tile.bits = bits;
    tile.coord = (viewIndex << 30) | (coord.y << 15) | coord.x;
    return tile;
}
uint GetUpscaleViewIndex(CapsuleShadowsUpscaleTile tile)    { return tile.coord >> 30; }
uint2 GetUpscaleTileCoord(CapsuleShadowsUpscaleTile tile)   { return uint2(tile.coord & 0x7fffU, (tile.coord >> 15) & 0x7fffU); }
uint GetUpscaleTileBits(CapsuleShadowsUpscaleTile tile)     { return tile.bits; }

uint GetCapsuleLayerMask(CapsuleOccluderData capsule)   { return (capsule.packedData >> 16) & 0xffU; }
uint GetCapsuleCasterType(CapsuleOccluderData capsule)  { return (capsule.packedData >> 8) & 0xffU; }
uint GetCapsuleCasterIndex(CapsuleOccluderData capsule) { return capsule.packedData & 0xffU; }

// store in gamma 2 to increase precision at the low end
float PackCapsuleVisibility(float visibility)   { return 1.f - sqrt(max(0.f, visibility)); }
float UnpackCapsuleVisibility(float texel)      { return Sq(1.f - texel); }
float4 UnpackCapsuleVisibility(float4 texels)   { return Sq(1.f - texels); }

#endif // ndef CAPSULE_SHADOWS_GLOBALS_DEF
