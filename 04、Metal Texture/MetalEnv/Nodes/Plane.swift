//
//  Plane.swift
//  MetalEnv
//
//  Created by karos li on 2021/7/15.
//

import MetalKit

class Plane: Node {
    var vertices: [Vertex] = [
        Vertex(position: SIMD3<Float>(-1,  1, 0),
               color: SIMD4<Float>(1, 0, 0, 1),
               textureCoords: SIMD2<Float>(0, 1)), // V0 左上
        Vertex(position: SIMD3<Float>(-1, -1, 0),
               color: SIMD4<Float>(0, 1, 0, 1),
               textureCoords: SIMD2<Float>(0, 0)), // V1 左下
        Vertex(position: SIMD3<Float>( 1, -1, 0),
               color: SIMD4<Float>(0, 0, 1, 1),
               textureCoords: SIMD2<Float>(1, 0)), // V2 右下
        Vertex(position: SIMD3<Float>( 1,  1, 0),
               color: SIMD4<Float>(1, 0, 1, 1),
               textureCoords: SIMD2<Float>(1, 1))  // V3 右上
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
    
    override func render(commandEncoder: MTLRenderCommandEncoder, deltaTime: Float) {
        super.render(commandEncoder: commandEncoder, deltaTime: deltaTime)
        
        guard let pipelineState = pipelineState else {
            return
        }
        
        time += deltaTime
        constants.moveBy = abs(sin(time)/2 + 0.5)
        
        commandEncoder.setRenderPipelineState(pipelineState)
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBytes(&constants, length: MemoryLayout<Constants>.stride, index: 1)
        
        commandEncoder.setFragmentTexture(texture, index: 0)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
    }
}

extension Plane: Texturable {}
