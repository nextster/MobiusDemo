//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef Shared_h
#define Shared_h

#include <simd/simd.h>

typedef struct
{
    float aspect;
    float time;
    float rad;
    float circleMul;
    float fireMul;
} Uniforms;

#endif /* Shared_h */

