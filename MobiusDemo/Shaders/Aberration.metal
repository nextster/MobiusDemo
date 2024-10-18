#include <metal_stdlib>
using namespace metal;

kernel void aberrationCompute(texture2d<half, access::write> output [[texture(0)]],
                              texture2d<half, access::sample> input [[texture(1)]],
                              uint2 gid [[thread_position_in_grid]]) {
    int width = output.get_width();
    int height = output.get_height();
    float2 uv = float2(gid) / float2(width, height);

    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::nearest);

    half abShift = abs(uv.x - 0.5) * 0.02;
    float2 uvr = uv;
    uvr.x -= abShift;
    float2 uvb = uv;
    uvb.x += abShift;

    half3 col = half3(input.sample(s, uvr).r,
                      input.sample(s, uv).g,
                      input.sample(s, uvb).b);
    output.write(half4(col, 1), gid);
}
