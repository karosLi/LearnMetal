//
//  Types.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import simd

struct Vertex {
    var position: vector_float2
    var textureCoords: vector_float2
    var textureIndex: simd_int1 = 0
}

struct Uniform {
    var modeMatrix = matrix4x4_indentify()
    var viewMatrix = matrix4x4_indentify()
    var projectionMatrix = matrix4x4_indentify()
}

struct InstanceUniform {
    /// 实例位置
    var center: vector_float2
    /// 实例大小
    var size: vector_float2
    /// 实例旋转弧度
    var radian: simd_float1
    /// 实例纹理索引
    var textureIndex: simd_int1 = 0
    /// 实例纹理坐标
    var textureFrame: vector_float4 = vector4(0, 0, 1, 1)
    /// 实例纹理旋转弧度
    var textureRadian: simd_float1 = 0
}
