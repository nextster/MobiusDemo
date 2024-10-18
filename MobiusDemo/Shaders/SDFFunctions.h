#ifndef SDFFunctions_h
#define SDFFunctions_h

#include <metal_stdlib>

using namespace metal;

// SDF
float unionSDF(float d1, float d2) {
    return min(d1, d2);
}
float intersectionSDF(float d1, float d2) {
    return max(d1, d2);
}
float differenceSDF(float d1, float d2) {
    return max(d1, -d2);
}

METAL_FUNC half smoothUnion(half d1, half d2, half k) {
    half h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

METAL_FUNC half smoothIntersection(half d1, half d2, half k) {
    half h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h);
}

float2 rot(float2 pos, float rotation) {
    half angle = rotation * M_PI_H * 2 * -1;
    half sine = sin(angle);
    half cosine = cos(angle);
    return float2(cosine * pos.x + sine * pos.y,
                 cosine * pos.y - sine * pos.x);
}

float2 translate(float2 pos, float2 translation) {
    return pos + translation;
}

float2 scale(float2 pos, half scale) {
    return pos / scale;
}

float circleSDF(float2 vec, float rad, float time) {
    float angle = atan2(vec.x, vec.y);
    float distortion = sin(angle * 5 + time);
    distortion += cos(angle * 3 - time);
    rad += distortion * 0.01;
    return length(vec) - rad;
}

float triangleSDF(float2 p, float2 q) {
    p.x = abs(p.x);
    float2 a = p - q*clamp(dot(p,q)/dot(q,q), 0.0, 1.0);
    float2 b = p - q*float2(clamp(p.x/q.x, 0.0, 1.0), 1.0);
    float k = sign( q.y );
    float d = min(dot( a, a ),dot(b, b));
    float s = max( k*(p.x*q.y-p.y*q.x),k*(p.y-q.y)  );
    return sqrt(d)*sign(s);
}

float parabolaSDF(float2 pos, float k) {
    pos.x = abs(pos.x);
    float ik = 1.0/k;
    float p = ik*(pos.y - 0.5*ik)/3.0;
    float q = 0.25*ik*ik*pos.x;
    float h = q*q - p*p*p;
    float r = sqrt(abs(h));
    float x = (h>0.0) ?
        pow(q+r,1.0/3.0) - pow(abs(q-r),1.0/3.0)*sign(r-q) :
        2.0*cos(atan2(r,q)/3.0)*sqrt(p);
    return length(pos-float2(x,k*x*x)) * sign(pos.x-x);
}

#endif /* SDFFunctions_h */
