//
//  Plane.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit
import simd

class Plane: Node {
    var vertices: [Vertex] = [
        Vertex(position: vector3(-250,  250, 0),
               color: vector4(1, 0, 0, 1),
               textureCoords: vector2(0, 1)), // V0 左上
        Vertex(position: vector3(-250, -250, 0),
               color: vector4(0, 1, 0, 1),
               textureCoords: vector2(0, 0)), // V1 左下
        Vertex(position: vector3(250, -250, 0),
               color: vector4(0, 0, 1, 1),
               textureCoords: vector2(1, 0)), // V2 右下
        Vertex(position: vector3(250,  250, 0),
               color: vector4(1, 0, 1, 1),
               textureCoords: vector2(1, 1))  // V3 右上
    ]
    
    var indices: [UInt16] = [
        0, 1, 2,
        2, 3, 0
    ]

    var uniform = Uniform()
    var time: Float = 0
    
    var pipelineState: MTLRenderPipelineState?
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    
    var texture: MTLTexture?
    
    var fragmentFunctionName: String = "fragment_shader"
    
    init(device: MTLDevice, imageName: String) {
        super.init()
        
        if let texture = setTexture(device: device, imageName: imageName) {
            self.texture = texture;
            fragmentFunctionName = "texture_fragment_shader"
        }
        
        buildBuffers(device: device)
        buildPipelineState(device: device)
    }
    
    private func buildBuffers(device: MTLDevice) {
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: [])
    }
    
    private func buildPipelineState(device: MTLDevice) {
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertex_shader")
        let fragmentFunction = library?.makeFunction(name: fragmentFunctionName)
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
    }
    
    override func render(commandEncoder: MTLRenderCommandEncoder, deltaTime: Float, viewPortSize: vector_uint2) {
        super.render(commandEncoder: commandEncoder, deltaTime: deltaTime, viewPortSize: viewPortSize)
        
        guard let pipelineState = pipelineState else {
            return
        }
        
        time += deltaTime
        
        var modelMatrix = matrix4x4_indentify()
        modelMatrix = matrix_multiply(modelMatrix, matrix4x4_rotation(angle: 45, axis: vector3(0, 0, 1.0)))
        
        uniform.modeMatrix = modelMatrix
        uniform.viewMatrix = matrix4x4_translate(x: 0, y: 0, z: -900)
        
        let projectionMatrix = matrix4x4_perspective(fovY: 45, aspect: Float(viewPortSize.x) / Float(viewPortSize.y), nearZ: 0.1, farZ: 1000)
//        let projectionMatrix = matrix4x4_ortho(left: -1, right: 1, bottom: -1, top: 1, nearZ: -1, farZ: 1)
//        let projectionMatrix = matrix4x4_ortho(left: -Float(viewPortSize.x) / 2.0, right: Float(viewPortSize.x) / 2.0, bottom: -Float(viewPortSize.y) / 2.0, top: Float(viewPortSize.y) / 2.0, nearZ: -1, farZ: 1)
        uniform.projectionMatrix = projectionMatrix
        
        commandEncoder.setRenderPipelineState(pipelineState)
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBytes(&uniform, length: MemoryLayout<Uniform>.stride, index: 1)
        
        commandEncoder.setFragmentTexture(texture, index: 0)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
    }
}

extension Plane: Texturable {}
