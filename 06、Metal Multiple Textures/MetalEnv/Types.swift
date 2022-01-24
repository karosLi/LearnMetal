//
//  Types.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import simd

struct Vertex {
    var position: vector_float3
    var color: vector_float4 = vector4(1, 1, 1, 1)
    var textureCoords: vector_float2
    var textureIndex: simd_int1 = 0
}

struct Uniform {
    var modeMatrix = matrix4x4_indentify()
    var viewMatrix = matrix4x4_indentify()
    var projectionMatrix = matrix4x4_indentify()
}
