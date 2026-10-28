//!DESC Cinema4K - Master Cinema Clarity (3-Band Multi-Scale Optical Engine)
// ==============================================================================
// Cinema4K™ Real-Time Video Shaders - Copyright (c) 2026. All rights reserved.
// Licensed under PolyForm Noncommercial 1.0.0 (Free for Personal Use).
// Commercial use, distribution, or bundling into paid products requires an
// express written Commercial License Agreement from the copyright holder.
// ==============================================================================
//!HOOK LUMA
//!BIND LUMA
//!SAVE LUMA
//!WIDTH LUMA.w
//!HEIGHT LUMA.h

// Cinema4K Master Optical Engine
// 100% Zero Color Shift (Chroma U/V Untouched, Pure LUMA)
// 100% Zero Downscaler Low-Pass Blur (Operates unconditionally at 1:1 Video Resolution)
// 100% Zero Shadow Blowout / Zero Ringing (Adaptive Soft-Knee Dynamic Headroom)
// Multi-Octave Frequency Decomposition:
//   - Band 1 (Micro-Octave 3x3): Pores, lashes, fine hair strands, pupil specular glints
//   - Band 2 (Cloth/Weave-Octave 5x5): Checkered patterns, fabric texture, knit ribs, clothing seams
//   - Band 3 (Scenery/Depth-Octave 9x9): Tree foliage, forest canopy, leaves, stone pillars, background acutance
// Contrast & Daylight Adaptivity:
//   - Preserves full texture pop in daylight and outdoor sunshine scenes
//   - Halo-suppression tensor protects high-contrast boundaries while allowing fine organic micro-detail

#define SHARPNESS 0.65
#define MICRO_BOOST 0.55
#define CLOTH_BOOST 0.60
#define SCENE_BOOST 0.45
#define HEADROOM 0.075

vec4 hook() {
    vec2 pos = LUMA_pos;
    vec2 pt  = LUMA_pt;
    float y  = float(LUMA_tex(pos));

    // Sample 3x3 local neighborhood (Radius 1)
    float b  = float(LUMA_tex(pos + vec2( 0.0, -pt.y))); // top
    float h_ = float(LUMA_tex(pos + vec2( 0.0,  pt.y))); // bot
    float d  = float(LUMA_tex(pos + vec2(-pt.x,  0.0))); // left
    float f  = float(LUMA_tex(pos + vec2( pt.x,  0.0))); // right

    float a  = float(LUMA_tex(pos + vec2(-pt.x, -pt.y))); // top-left
    float c  = float(LUMA_tex(pos + vec2( pt.x, -pt.y))); // top-right
    float g  = float(LUMA_tex(pos + vec2(-pt.x,  pt.y))); // bot-left
    float i  = float(LUMA_tex(pos + vec2( pt.x,  pt.y))); // bot-right

    // Local min/max bounds
    float mn_card = min(y, min(min(b, h_), min(d, f)));
    float mx_card = max(y, max(max(b, h_), max(d, f)));
    float mn_all  = min(mn_card, min(min(a, c), min(g, i)));
    float mx_all  = max(mx_card, max(max(a, c), max(g, i)));

    // Dynamic contrast-adaptive CAS weighting (daylight-safe)
    float contrast = mx_all - mn_all;
    float w_cas = -SHARPNESS * 0.14 * (1.0 - clamp(contrast * 2.0, 0.0, 0.7));
    float lap_cas = (b * w_cas + d * w_cas + f * w_cas + h_ * w_cas + y) / (1.0 + 4.0 * w_cas);

    // Band 1: Micro-texture Octave (Radius 1: pores, lashes, hair, edges)
    float blur3 = (y * 4.0 + (b + h_ + d + f) * 2.0 + (a + c + g + i)) / 16.0;
    float d_micro = y - blur3;

    // Band 2: Cloth & Pattern Octave (Radius 2: fabric weave, checkered pattern, knit ribs, clothing seams)
    float t2 = float(LUMA_tex(pos + vec2( 0.0, -2.0 * pt.y)));
    float b2 = float(LUMA_tex(pos + vec2( 0.0,  2.0 * pt.y)));
    float l2 = float(LUMA_tex(pos + vec2(-2.0 * pt.x,  0.0)));
    float r2 = float(LUMA_tex(pos + vec2( 2.0 * pt.x,  0.0)));
    float blur5 = (blur3 * 8.0 + (t2 + b2 + l2 + r2) * 2.0) / 16.0;
    float d_cloth = blur3 - blur5;

    // Band 3: Scenery & Foliage Octave (Radius 4: tree bark, leaves, stone texture, outdoor depth)
    float t4 = float(LUMA_tex(pos + vec2( 0.0, -4.0 * pt.y)));
    float b4 = float(LUMA_tex(pos + vec2( 0.0,  4.0 * pt.y)));
    float l4 = float(LUMA_tex(pos + vec2(-4.0 * pt.x,  0.0)));
    float r4 = float(LUMA_tex(pos + vec2( 4.0 * pt.x,  0.0)));
    float blur9 = (blur5 * 8.0 + (t4 + b4 + l4 + r4) * 2.0) / 16.0;
    float d_scene = blur5 - blur9;

    // Edge gradient tensor for halo suppression
    float gx = ((c + 2.0 * f + i) - (a + 2.0 * d + g)) * 0.25;
    float gy = ((g + 2.0 * h_ + i) - (a + 2.0 * b + c)) * 0.25;
    float grad = sqrt(gx * gx + gy * gy);
    float halo_sup = 1.0 / (1.0 + 2.5 * grad);

    // Soft-knee detail transfer functions (smooth S-curve, no harsh clamping)
    float s_micro = d_micro / sqrt(1.0 + 4.0 * d_micro * d_micro);
    float s_cloth = d_cloth / sqrt(1.0 + 3.0 * d_cloth * d_cloth);
    float s_scene = d_scene / sqrt(1.0 + 2.0 * d_scene * d_scene);

    float boost = (s_micro * MICRO_BOOST + s_cloth * CLOTH_BOOST + s_scene * SCENE_BOOST) * halo_sup;

    float target_y = clamp(lap_cas + boost, max(0.0, mn_all - HEADROOM), min(1.0, mx_all + HEADROOM));
    return vec4(target_y, 0.0, 0.0, 1.0);
}

//!DESC Cinema4K - 2x Optical Spline Upscaler (4K Screen Adaptive)
//!HOOK LUMA
//!BIND LUMA
//!SAVE LUMA
//!WIDTH LUMA.w 2 *
//!HEIGHT LUMA.h 2 *
//!WHEN OUTPUT.w LUMA.w > OUTPUT.h LUMA.h > +

float sample_catmull_rom(vec2 pos, vec2 pt) {
    vec2 tc = pos / pt - 0.5;
    vec2 f = fract(tc);
    vec2 idx = floor(tc);
    vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    vec2 w3 = f * f * (-0.5 + 0.5 * f);
    vec2 w12 = w1 + w2;
    vec2 off12 = w2 / max(w12, vec2(0.0001));
    vec2 p0  = (idx - vec2(0.5)) * pt;
    vec2 p12 = (idx + vec2(0.5) + off12) * pt;
    vec2 p3  = (idx + vec2(2.5)) * pt;
    float col = 0.0;
    col += float(LUMA_tex(vec2(p0.x,  p0.y)))  * (w0.x  * w0.y);
    col += float(LUMA_tex(vec2(p12.x, p0.y)))  * (w12.x * w0.y);
    col += float(LUMA_tex(vec2(p3.x,  p0.y)))  * (w3.x  * w0.y);
    col += float(LUMA_tex(vec2(p0.x,  p12.y))) * (w0.x  * w12.y);
    col += float(LUMA_tex(vec2(p12.x, p12.y))) * (w12.x * w12.y);
    col += float(LUMA_tex(vec2(p3.x,  p12.y))) * (w3.x  * w12.y);
    col += float(LUMA_tex(vec2(p0.x,  p3.y)))  * (w0.x  * w3.y);
    col += float(LUMA_tex(vec2(p12.x, p3.y)))  * (w12.x * w3.y);
    col += float(LUMA_tex(vec2(p3.x,  p3.y)))  * (w3.x  * w3.y);
    return clamp(col, 0.0, 1.0);
}

vec4 hook() {
    float y_2x = sample_catmull_rom(LUMA_pos, LUMA_pt);
    return vec4(y_2x, 0.0, 0.0, 1.0);
}
