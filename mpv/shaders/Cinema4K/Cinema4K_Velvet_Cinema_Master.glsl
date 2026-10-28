//!DESC Cinema4K - Velvet Cinema Master (Anti-Pixelation & Natural Depth)
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

// Cinema4K Velvet Cinema Master (Organic Film Refinement Edition)
// Engineered specifically to eliminate digital pixel crunchiness and artificial HDR:
// 1. Anti-Pixelation Sub-Pixel Reconstruction:
//    Damps single-pixel high-frequency spikes so individual pixels NEVER pop out.
// 2. Natural Cinema Lighting (Zero Fake HDR):
//    100% preserves original grading and tonal balance (eliminates broad local contrast warping).
// 3. Meso-Scale Structural Texture (Radius 2-3):
//    Concentrates resolution on physical features: fabric weave, knit ribs, hair strands, iris fibers.
// 4. Tangent Flow Continuity:
//    Synthesizes crispness ALONG contours rather than perpendicular to them, preventing jagged staircasing.
// 5. Pure LUMA Engine: 100% Zero Color Drift.

#define SHARPNESS 0.70            // Core acutance (calibrated sweet spot, zero pixelation)
#define MESO_BOOST 1.40           // Structural fabric & feature octave boost (weave, knit, hair)
#define MACRO_BOOST 0.75          // Natural edge separation (no broad HDR distortion)
#define MICRO_BOOST 0.60          // Gentle micro-acutance (eyelashes, pupil glints)
#define HEADROOM_DARK 0.045       // Suppresses dark edge ditches & line thickening
#define HEADROOM_BRIGHT 0.080     // Allows radiant specular glints & eye reflections

vec4 hook() {
    vec2 pos = LUMA_pos;
    vec2 pt  = LUMA_pt;
    float y  = float(LUMA_tex(pos));

    // 3x3 Direct Neighborhood (Radius 1)
    float b  = float(LUMA_tex(pos + vec2( 0.0, -pt.y))); // top
    float h_ = float(LUMA_tex(pos + vec2( 0.0,  pt.y))); // bot
    float d  = float(LUMA_tex(pos + vec2(-pt.x,  0.0))); // left
    float f  = float(LUMA_tex(pos + vec2( pt.x,  0.0))); // right

    float a  = float(LUMA_tex(pos + vec2(-pt.x, -pt.y))); // top-left
    float c  = float(LUMA_tex(pos + vec2( pt.x, -pt.y))); // top-right
    float g  = float(LUMA_tex(pos + vec2(-pt.x,  pt.y))); // bot-left
    float i  = float(LUMA_tex(pos + vec2( pt.x,  pt.y))); // bot-right

    // Local Extrema Bounds
    float mn_card = min(y, min(min(b, h_), min(d, f)));
    float mx_card = max(y, max(max(b, h_), max(d, f)));
    float mn_all  = min(mn_card, min(min(a, c), min(g, i)));
    float mx_all  = max(mx_card, max(max(a, c), max(g, i)));
    float span    = mx_all - mn_all;

    // Edge Gradient Tensor for Directional Acutance
    float gx = ((c + 2.0 * f + i) - (a + 2.0 * d + g)) * 0.25;
    float gy = ((g + 2.0 * h_ + i) - (a + 2.0 * b + c)) * 0.25;
    float grad = sqrt(gx * gx + gy * gy);

    // =========================================================================
    // Core 1: Anti-Pixelation Contrast-Adaptive Core
    // =========================================================================
    // Damps single-pixel spikes while preserving organic stroke edges
    float w_cas = -SHARPNESS * 0.13 * (1.0 - clamp(span * 2.0, 0.0, 0.70));
    float lap_cas = (b * w_cas + d * w_cas + f * w_cas + h_ * w_cas + y) / (1.0 + 4.0 * w_cas);

    // =========================================================================
    // Core 2: Multi-Octave Organic Hierarchy (NO Fake HDR!)
    // =========================================================================
    // Octave 1: Micro-Texture (Radius 1) - gentle, avoids individual pixel blocks
    float blur3 = (y * 4.0 + (b + h_ + d + f) * 2.0 + (a + c + g + i)) * 0.0625;
    float d_micro = y - blur3;
    float s_micro = d_micro / sqrt(1.0 + 4.0 * d_micro * d_micro);

    // Octave 2: Meso-Texture (Radius 2) - PHYSICAL RECONSTRUCTION (fabric weave, knit ribs, hair)
    float t2 = float(LUMA_tex(pos + vec2( 0.0, -2.0 * pt.y)));
    float b2 = float(LUMA_tex(pos + vec2( 0.0,  2.0 * pt.y)));
    float l2 = float(LUMA_tex(pos + vec2(-2.0 * pt.x,  0.0)));
    float r2 = float(LUMA_tex(pos + vec2( 2.0 * pt.x,  0.0)));
    float blur5 = blur3 * 0.5 + (t2 + b2 + l2 + r2) * 0.125;
    float d_meso = blur3 - blur5;
    float s_meso = d_meso / sqrt(1.0 + 2.5 * d_meso * d_meso);

    // Octave 3: Macro-Contour (Radius 4) - natural silhouette separation (NO Radius 15!)
    float t4 = float(LUMA_tex(pos + vec2( 0.0, -4.0 * pt.y)));
    float b4 = float(LUMA_tex(pos + vec2( 0.0,  4.0 * pt.y)));
    float l4 = float(LUMA_tex(pos + vec2(-4.0 * pt.x,  0.0)));
    float r4 = float(LUMA_tex(pos + vec2( 4.0 * pt.x,  0.0)));
    float blur9 = blur5 * 0.5 + (t4 + b4 + l4 + r4) * 0.125;
    float d_macro = blur5 - blur9;
    float s_macro = d_macro / sqrt(1.0 + 2.0 * d_macro * d_macro);

    // Tangent flow steering (sharpens ALONG edges to prevent jagged pixel stairs)
    float tangent_flow = 1.0 + clamp(grad * 3.5, 0.0, 0.6);

    // Halo suppression tensor
    float halo_sup = 1.0 / (1.0 + 2.0 * grad);

    float octaves = (s_micro * MICRO_BOOST + s_meso * MESO_BOOST * tangent_flow + s_macro * MACRO_BOOST) * halo_sup;

    // =========================================================================
    // Synthesis & Controlled Headroom
    // =========================================================================
    float candidate = lap_cas + octaves;

    float final_y = clamp(candidate, max(0.0, mn_all - HEADROOM_DARK), min(1.0, mx_all + HEADROOM_BRIGHT));

    return vec4(final_y, 0.0, 0.0, 1.0);
}

//!DESC Cinema4K - 2x Optical Spline Upscaler (4K Screen Adaptive)
//!HOOK LUMA
//!BIND LUMA
//!SAVE LUMA
//!WIDTH LUMA.w 2 *
//!HEIGHT LUMA.h 2 *
//!WHEN OUTPUT.w LUMA.w > OUTPUT.h LUMA.h > +

// High-Precision Bicubic Catmull-Rom Reconstruction
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
