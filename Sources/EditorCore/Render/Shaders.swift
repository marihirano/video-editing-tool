/// Metal shader source, compiled when the app starts (there's no Metal compiler without Xcode).
enum Shaders {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    // Must match FrameUniforms in FrameLayout.swift.
    struct FrameUniforms {
        float4 background;
        float4 gradientA;
        float4 gradientB;
        float4 bgParams;     // kind, gradient angle
        float4 wallpaper0, wallpaper1, wallpaper2, wallpaper3;
        float4 contentRect;  // where the video sits on the canvas, 0–1, origin top-left
        float4 sourceRect;   // which part of the source frame to show, 0–1, origin top-left
        float4 shape;        // corner radius, shadow opacity, shadow blur, shadow offset (pixels)
        float4 canvas;       // canvas size in pixels
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

    // Distance from point p to a rounded box (negative inside), in pixels.
    float roundedBoxDistance(float2 p, float2 halfSize, float radius) {
        float2 q = abs(p) - halfSize + radius;
        return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    }

    float4 backgroundColor(float2 uv, constant FrameUniforms &u, texture2d<float> image) {
        int kind = int(u.bgParams.x + 0.5);
        float2 size = u.canvas.xy;
        if (kind == 0) {
            // Wallpaper: four colours blended smoothly, one near each corner.
            float2 pts[4] = { float2(0.1, 0.1), float2(0.9, 0.15), float2(0.15, 0.9), float2(0.9, 0.85) };
            float4 cols[4] = { u.wallpaper0, u.wallpaper1, u.wallpaper2, u.wallpaper3 };
            float4 sum = 0.0; float total = 0.0;
            for (int i = 0; i < 4; i++) {
                float2 d = (uv - pts[i]) * float2(size.x / size.y, 1.0);
                float w = 1.0 / pow(dot(d, d) + 0.04, 1.6);
                sum += cols[i] * w; total += w;
            }
            return float4((sum / total).rgb, 1.0);
        }
        if (kind == 1) {
            float2 dir = float2(sin(u.bgParams.y), -cos(u.bgParams.y));
            float2 p = (uv - 0.5) * size;
            float t = dot(p, dir) / (abs(dir.x) * size.x + abs(dir.y) * size.y) + 0.5;
            return float4(mix(u.gradientA, u.gradientB, clamp(t, 0.0, 1.0)).rgb, 1.0);
        }
        if (kind == 3) {
            // The user's picture, scaled to fill the canvas.
            constexpr sampler s(filter::linear, address::clamp_to_edge);
            float imageAspect = float(image.get_width()) / float(image.get_height());
            float canvasAspect = size.x / size.y;
            float2 t = uv - 0.5;
            if (canvasAspect > imageAspect) { t.y *= imageAspect / canvasAspect; } else { t.x *= canvasAspect / imageAspect; }
            return float4(image.sample(s, t + 0.5).rgb, 1.0);
        }
        return float4(u.background.rgb, 1.0);
    }

    fragment float4 frameFragment(VOut in [[stage_in]],
                                  constant FrameUniforms &u [[buffer(0)]],
                                  texture2d<float> source [[texture(0)]],
                                  texture2d<float> backgroundImage [[texture(1)]]) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float4 color = backgroundColor(in.uv, u, backgroundImage);

        // Geometry in canvas pixels.
        float2 px = in.uv * u.canvas.xy;
        float2 center = (u.contentRect.xy + u.contentRect.zw * 0.5) * u.canvas.xy;
        float2 halfSize = u.contentRect.zw * 0.5 * u.canvas.xy;
        float radius = min(u.shape.x, min(halfSize.x, halfSize.y));

        // Drop shadow: a softened copy of the rounded box, moved down.
        float blur = max(u.shape.z, 0.001);
        float shadowDistance = roundedBoxDistance(px - center - float2(0.0, u.shape.w), halfSize, radius);
        float shadow = u.shape.y * (1.0 - smoothstep(-blur * 0.6, blur * 0.6, shadowDistance));
        color.rgb *= (1.0 - shadow);

        // The video, with anti-aliased rounded corners (one pixel of softness).
        float inside = clamp(0.5 - roundedBoxDistance(px - center, halfSize, radius), 0.0, 1.0);
        if (inside > 0.0) {
            float2 local = clamp((in.uv - u.contentRect.xy) / u.contentRect.zw, 0.0, 1.0);
            float2 suv = u.sourceRect.xy + local * u.sourceRect.zw;
            // When shrinking a big recording, average four samples so small text stays clean.
            float2 footprint = fwidth(suv) * 0.25;
            float4 c = source.sample(s, suv + float2(-footprint.x, -footprint.y * 0.5))
                     + source.sample(s, suv + float2( footprint.x,  footprint.y * 0.5))
                     + source.sample(s, suv + float2( footprint.x * 0.5, -footprint.y))
                     + source.sample(s, suv + float2(-footprint.x * 0.5,  footprint.y));
            color.rgb = mix(color.rgb, (c * 0.25).rgb, inside);
        }
        return float4(color.rgb, 1.0);
    }
    """
}
