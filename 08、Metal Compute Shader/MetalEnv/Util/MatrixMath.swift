//
//  MatrixMath.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/19.
//

import simd

let PI = Float.pi

func radians(fromDegrees degrees: Float) -> Float {
    return (degrees / 180) * PI
}

func degree(fromRadians radians: Float) -> Float {
    return (radians / PI) * 180
}

extension Float {
    var radiansToDegrees: Float {
        return (self / PI) * 180
    }
    var degreesToRadians: Float {
        return (self / 180) * PI
    }
}

func matrix4x4_indentify() -> matrix_float4x4 {
    return simd_float4x4(vector4(1.0, 0.0, 0.0, 0.0),
                         vector4(0.0, 1.0, 0.0, 0.0),
                         vector4(0.0, 0.0, 1.0, 0.0),
                         vector4(0.0, 0.0, 0.0, 1.0)
    )
}

func matrix4x4_translate(x: Float, y: Float, z: Float) -> matrix_float4x4 {
    return simd_float4x4(vector4(1.0, 0.0, 0.0, 0.0),
                         vector4(0.0, 1.0, 0.0, 0.0),
                         vector4(0.0, 0.0, 1.0, 0.0),
                         vector4(x,   y,   z,   1.0)
    )
}

func matrix4x4_scale(x: Float, y: Float, z: Float) -> matrix_float4x4  {
    return simd_float4x4(vector4(x,   0.0, 0.0, 0.0),
                         vector4(0.0, y,   0.0, 0.0),
                         vector4(0.0, 0.0, z,   0.0),
                         vector4(0.0, 0.0, 0.0, 1.0)
    )
}

func matrix4x4_rotation(angle: Float, axis: vector_float3) -> matrix_float4x4  {
    let normalisedAxis = normalize(axis)
    if normalisedAxis.x.isNaN || normalisedAxis.y.isNaN || normalisedAxis.z.isNaN {
        return matrix_identity_float4x4
    }
    let ct = cosf(angle)
    let st = sinf(angle)
    let ci = 1 - ct
    let x = normalisedAxis.x
    let y = normalisedAxis.y
    let z = normalisedAxis.z
    return simd_float4x4(vector4(ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                         vector4(x * y * ci - z * st, ct + y * y * ci, z * y * ci + x * st, 0),
                         vector4(x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci, 0),
                         vector4(0.0, 0.0, 0.0, 1.0))
}

///  Metal 是左手坐标系
func matrix4x4_perspective(fovY: Float, aspect: Float, nearZ: Float, farZ: Float) -> matrix_float4x4  {
    let ys: Float = 1.0 / tanf(fovY * 0.5)
    let xs: Float = ys / aspect
    let zs: Float = farZ / (nearZ-farZ)
    return simd_float4x4(vector4(xs, 0.0, 0.0, 0.0),
                         vector4(0.0, ys, 0.0, 0.0),
                         vector4(0.0, 0.0, zs, -1.0),
                         vector4(0.0, 0.0, zs*nearZ, 0.0))
}

func matrix4x4_ortho(left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float) -> matrix_float4x4  {
    return simd_float4x4(vector4(2.0 / (right - left),              0.0,                                0.0,                                0.0),
                         vector4(0.0,                               2.0 / (top - bottom),               0.0,                                0.0),
                         vector4(0.0,                               0.0,                                1.0 / (farZ - nearZ),               0.0),
                         vector4(-(right + left) / (right - left),  -(top + bottom) / (top - bottom),   -nearZ / (farZ - nearZ),            1.0)
    )
}

func matrix4x4_look_at(eye: vector_float3, centre: vector_float3, up: vector_float3) -> matrix_float4x4 {
    let z = normalize(eye-centre)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    let t = vector3(-dot(x, eye), -dot(y, eye), -dot(z, eye))
    return simd_float4x4(vector4(x.x, y.x, z.x, 0.0),
                       vector4(x.y, y.y, z.y, 0.0),
                       vector4(x.z, y.z, z.z, 0.0),
                       vector4(t.x, t.y, t.z, 1.0))
}
