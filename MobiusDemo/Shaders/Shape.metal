// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "Shared.h"
#import "SDFFunctions.h"

#include <metal_stdlib>

using namespace metal;

#define GLASS_REFRACTION 0.125

float2 squarifyUV(float2 uv, float aspect) {
    uv.y -= 0.5;
    uv.y /= aspect;
    uv.y += 0.5;
    return uv;
}

float2 glass(float2 in) {
    float stripesCount = 22;
    // умножаем координату на количество полосок
    float xShift = fract(in.x * stripesCount) - 0.5;
    in.x += xShift * GLASS_REFRACTION;
    return in;
}

float fireTopSDF(float2 pos, float rad, float time, float direction) {
    float trianglesCount = 6;

    // определяем, насколько мы далеко от горизонтального центра
    float distFromCenter = (pos.x * pos.x) / rad * 1.5;
    pos.y -= distFromCenter / 2;

    // добавляем немного асимметрии
    if (direction > 0) { pos.x += sin(time) * 0.05; }

    // поворачиваем треугольники наружу от центра
    pos = rot(pos, -pos.x * 0.1);

    // двигаем координату X в центр огня
    pos.x += sign(pos.x) * fract(time) / trianglesCount;

    // задаём несколько треугольников
    pos.x = fract(pos.x * trianglesCount) - 0.5;

    // смещаем треугольники выше
    pos.y += rad;

    // определяем ширину основания треугольника, чем дальше от центра — тем меньше
    float height = 1 - distFromCenter;

    float width = 0.5 / rad;
    return triangleSDF(pos, float2(width, height));
}

float fireSDF(float2 pos, float rad, float time) {
    // добавляем distortion
    pos.x += sin(pos.y * 10.0 + time) * 0.015;
    pos.y += cos(pos.x * 10.0 + time * 0.7) * 0.01;

    float fireTopDist = fireTopSDF(pos, rad, time, 1);;

    // модифицируем координаты для параболы
    float2 parabolaPos = pos;
    parabolaPos.y *= -1;
    parabolaPos.y += rad * 1.25;

    // 2.5 — коэффициент кривизны параболы
    float parabolaDist = parabolaSDF(parabolaPos, 2.5);

    return smoothIntersection(parabolaDist, fireTopDist, 0.1);
}

kernel void computeShape(texture2d<float, access::write> output [[texture(0)]],
                         constant Uniforms & uniforms [[ buffer(0) ]],
                         uint2 gid [[thread_position_in_grid]]) {
    int width = output.get_width();
    int height = output.get_height();
    float2 pos = float2(gid);
    float2 uv = pos / float2(width, height);
    uv = squarifyUV(uv, uniforms.aspect);
    uv = glass(uv);

    float2 center = float2(0.5, 0.5);
    float2 vec = uv - center;

    float dist = 0;

    if (uniforms.circleMul > 0) {
        dist += circleSDF(vec, uniforms.rad, uniforms.time) * uniforms.circleMul;
    }
    if (uniforms.fireMul > 0) {
        dist += fireSDF(vec, uniforms.rad, uniforms.time)  * uniforms.fireMul;
    }

    float outputColor = step(dist, 0);

    if (dist > 0) {
        float glow = dist / (uniforms.rad / 6);
        glow = 1 - glow; // invert
        outputColor = mix(0, 1, glow);
    } else {
        outputColor = 1;
    }

    output.write(outputColor, gid);
}
