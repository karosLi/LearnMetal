//
//  Plane.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

class Plane: Node {
    var vertices: [Vertex] = [
        Vertex(position: SIMD3<Float>(-1,  1, 0), color: SIMD4<Float>(1, 0, 0, 1)), // V0
        Vertex(position: SIMD3<Float>(-1, -1, 0), color: SIMD4<Float>(0, 1, 0, 1)), // V1
        Vertex(position: SIMD3<Float>( 1, -1, 0), color: SIMD4<Float>(0, 0, 1, 1)), // V2
        Vertex(position: SIMD3<Float>( 1,  1, 0), color: SIMD4<Float>(1, 0, 1, 1))  // V3
    ]
    
    var indices: [UInt16] = [
        0, 1, 2,
        2, 3, 0
    ]
    
    struct Constants {
        var moveBy: Float = 0
    }

    var constants = Constants()
    var time: Float = 0
    
    var pipelineState: MTLRenderPipelineState?
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    
    init(device: MTLDevice) {
        super.init()
        buildBuffers(device: device)
    }
    
    private func buildBuffers(device: MTLDevice) {
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: [])
    }
}
