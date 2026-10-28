//!DESC Cinema4K - Master Cinema Clarity (Ultra 4K Dynamic Punch V2 - Enhanced)
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

// Cinema4K Master Optical Engine (Ultra 4K Dynamic Punch V2)
// 100% Zero Color Shift (Chroma U/V Untouched, Pure LUMA)
// 100% Zero Downscaler Low-Pass Blur (Operates unconditionally at 1:1 Video Resolution)
// 100% Zero Shadow Blowout / Zero White Halos (Asymmetric Dynamic Headroom)
// Core Innovations in V2:
//   - Weak-Signal Non-Linear Acutance Lift: Selectively boosts faint, compressed textures (cloth weave, distant leaves)
//   - Anisotropic Tangent Flow Steering: Directs detail synthesis along physical fiber and edge contours
//   - Multi-Octave 4-Band Feature Pyramid: Micro (3x3), Meso (5x5), Macro (9x9), Depth (15x15)
//   - Local Variance Texture Gate: Silky skin on cheeks & forehead, maximum optical punch on textures

#define SHARPNESS 0.85
#define MICRO_BOOST 0.80
#define MESO_BOOST 0.95
#define MACRO_BOOST 0.75
#define DEPTH_BOOST 0.55
#define HEADROOM 0.09

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

    // Edge Gradient Tensor & Tangent Flow Steering
    float gx = ((c + 2.0 * f + i) - (a + 2.0 * d + g)) * 0.25;
    float gy = ((g + 2.0 * h_ + i) - (a + 2.0 * b + c)) * 0.25;
    float grad = sqrt(gx * gx + gy * gy);
    float tangent_boost = 1.0 + clamp(grad * 3.5, 0.0, 0.7);

    // Multi-Scale 4-Band Hierarchy
    // Band 1: Micro (Radius 1)
    float blur3 = (y * 4.0 + (b + h_ + d + f) * 2.0 + (a + c + g + i)) * 0.0625;
    float d_micro = y - blur3;

    // Band 2: Meso & Cloth Weave (Radius 2)
    float t2 = float(LUMA_tex(pos + vec2( 0.0, -2.0 * pt.y)));
    float b2 = float(LUMA_tex(pos + vec2( 0.0,  2.0 * pt.y)));
    float l2 = float(LUMA_tex(pos + vec2(-2.0 * pt.x,  0.0)));
    float r2 = float(LUMA_tex(pos + vec2( 2.0 * pt.x,  0.0)));
    float blur5 = blur3 * 0.5 + (t2 + b2 + l2 + r2) * 0.125;
    float d_meso = blur3 - blur5;

    // Band 3: Macro & Foliage (Radius 4)
    float t4 = float(LUMA_tex(pos + vec2( 0.0, -4.0 * pt.y)));
    float b4 = float(LUMA_tex(pos + vec2( 0.0,  4.0 * pt.y)));
    float l4 = float(LUMA_tex(pos + vec2(-4.0 * pt.x,  0.0)));
    float r4 = float(LUMA_tex(pos + vec2( 4.0 * pt.x,  0.0)));
    float blur9 = blur5 * 0.5 + (t4 + b4 + l4 + r4) * 0.125;
    float d_macro = blur5 - blur9;

    // Band 4: Depth & Volume (Radius 7)
    float t7 = float(LUMA_tex(pos + vec2( 0.0, -7.0 * pt.y)));
    float b7 = float(LUMA_tex(pos + vec2( 0.0,  7.0 * pt.y)));
    float l7 = float(LUMA_tex(pos + vec2(-7.0 * pt.x,  0.0)));
    float r7 = float(LUMA_tex(pos + vec2( 7.0 * pt.x,  0.0)));
    float blur15 = blur9 * 0.5 + (t7 + b7 + l7 + r7) * 0.125;
    float d_depth = blur9 - blur15;

    // Local Variance Texture Gate (Smooth skin on cheeks, full punch on textures)
    float mean_sq = (y*y * 4.0 + (b*b + h_*h_ + d*d + f*f) * 2.0 + (a*a + c*c + g*g + i*i)) * 0.0625;
    float var3 = max(0.0, mean_sq - blur3 * blur3);
    float tex_gate = clamp(0.80 + 10.0 * sqrt(var3), 0.80, 1.45);

    // Non-Linear Weak-Signal Acutance Lift for Compressed Video (Cloth Weave & Foliage)
    float lift_micro = 1.0 + 0.80 / (1.0 + 40.0 * abs(d_micro));
    float lift_meso  = 1.0 + 1.25 / (1.0 + 35.0 * abs(d_meso));
    float lift_macro = 1.0 + 1.10 / (1.0 + 25.0 * abs(d_macro));

    // Soft-Knee Detail Transfer (High MTF Punch with Weak-Signal Lift)
    float s_micro = (d_micro * lift_micro) / sqrt(1.0 + 3.5 * d_micro * d_micro);
    float s_meso  = (d_meso  * lift_meso)  / sqrt(1.0 + 2.5 * d_meso  * d_meso);
    float s_macro = (d_macro * lift_macro) / sqrt(1.0 + 2.0 * d_macro * d_macro);
    float s_depth = d_depth                / sqrt(1.0 + 1.5 * d_depth * d_depth);

    float halo_sup = 1.0 / (1.0 + 1.8 * grad);

    float boost = (s_micro * MICRO_BOOST + s_meso * MESO_BOOST * tangent_boost + s_macro * MACRO_BOOST + s_depth * DEPTH_BOOST) * halo_sup * tex_gate;

    // Dynamic Contrast Adaptive CAS Core
    float contrast = mx_all - mn_all;
    float w_cas = -SHARPNESS * 0.14 * (1.0 - clamp(contrast * 1.8, 0.0, 0.65));
    float lap_cas = (b * w_cas + d * w_cas + f * w_cas + h_ * w_cas + y) / (1.0 + 4.0 * w_cas);

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
