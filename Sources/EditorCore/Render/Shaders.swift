/// Metal shader source, compiled when the app starts (there's no Metal compiler without Xcode).
enum Shaders {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    // Must match FrameUniforms in FrameLayout.swift.
    struct FrameUniforms {
        float4 background;   // RGBA
        float4 contentRect;  // where the video sits on the canvas, 0–1, origin top-left
        float4 sourceRect;   // which part of the source frame to show, 0–1, origin top-left
    };

    struct VOut { float4 position [[position]]; float2 uv; };

    // One triangle that covers the whole target.
    vertex VOut fullscreenVertex(uint vid [[vertex_id]]) {
        float2 p = float2((vid << 1) & 2, vid & 2);
        VOut o;
        o.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
        o.uv = float2(p.x, 1.0 - p.y);
        return o;
    }

    fragment float4 frameFragment(VOut in [[stage_in]],
                                  constant FrameUniforms &u [[buffer(0)]],
                                  texture2d<float> source [[texture(0)]]) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float2 local = (in.uv - u.contentRect.xy) / u.contentRect.zw;
        if (any(local < 0.0) || any(local > 1.0)) { return u.background; }

        float2 suv = u.sourceRect.xy + local * u.sourceRect.zw;
        // When shrinking a big recording, average four samples so small text stays clean.
        float2 footprint = fwidth(suv) * 0.25;
        float4 c = source.sample(s, suv + float2(-footprint.x, -footprint.y * 0.5))
                 + source.sample(s, suv + float2( footprint.x,  footprint.y * 0.5))
                 + source.sample(s, suv + float2( footprint.x * 0.5, -footprint.y))
                 + source.sample(s, suv + float2(-footprint.x * 0.5,  footprint.y));
        return float4((c * 0.25).rgb, 1.0);
    }
    """
}
