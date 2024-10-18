#include <metal_stdlib>
using namespace metal;

kernel void blurCompute(texture2d<half, access::write> output [[texture(0)]],
                        texture2d<half, access::sample> input [[texture(1)]],
                        uint2 gid [[thread_position_in_grid]]) {

    int width = output.get_width();
    int height = output.get_height();
    float2 uv = float2(gid) / float2(width, height);

    float dist = max(0.0, length(uv - 0.5) - 0.1);

    half directions = 8;
    half quality = 4;
    half rad = max(0.0h, half(dist) / 10);

    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::nearest);

    half3 col = input.sample(s, uv).rgb;

    if (rad > 0) {
        half twopi = M_PI_F * 2;
        half step = twopi / directions;
        for (half a = 0; a < twopi; a += step) {
            for (half i = 1./quality; i <= 1.; i += 1./quality) {
                float2 coord = uv + float2(cos(a), sin(a)) * rad * i;
                col += input.sample(s, coord).rgb;
            }
        }
        col /= quality * directions + 1;
    }

    output.write(half4(col, 1), gid);
}
