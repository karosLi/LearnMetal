//
//  TexturesRenderer.swift
//  MetalEnv
//
//  Created by karos li on 2021/8/27.
//

import MetalKit

/// https://developer.apple.com/documentation/metal/
class TexturesRenderer: NSObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var viewPortSize: vector_uint2 = vector_uint2(1,1)
    
    private var computePipelineState: MTLComputePipelineState?
    private var computeBufferA: MTLBuffer!
    private var computeBufferB: MTLBuffer!
    private var computeBufferResult: MTLBuffer!
    
    private var renderPipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!

    private var samplerState: MTLSamplerState?
    private var textures = [MTLTexture]()
    private var instances = [InstanceUniform]()
    private var instancesBuffer: MTLBuffer!
    
    private var uniform = Uniform()
    
    private var myCaptureScope: MTLCaptureScope?
    
    /// 单位正方形顶点数据
    private let vertices: [Vertex] = [
        Vertex(position: vector2(-0.5,  0.5),
               textureCoords: vector2(0, 1)), // V0 左上
        Vertex(position: vector2(-0.5, -0.5),
               textureCoords: vector2(0, 0)), // V1 左下
        Vertex(position: vector2(0.5, -0.5),
               textureCoords: vector2(1, 0)), // V2 右下
        Vertex(position: vector2(0.5,  0.5),
               textureCoords: vector2(1, 1)),  // V3 右上
    ]
    
    private let primitiveType: MTLPrimitiveType = .triangle
    
    /// 单位正方形顶点索引
    private var indices: [UInt16] {
        switch primitiveType {
        case .triangleStrip:
            return [
                1, 2, 0,
                2, 3, 0
            ]
        case .triangle:
            return [
                0, 1, 2,
                2, 3, 0
            ]
        default:
            return [
                0, 1, 2,
                2, 3, 0
            ]
        }
    }
    
    init(device: MTLDevice, size: CGSize) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        super.init()
        updateSize(size: size)
        buildComputePipelineState()
        buildVertexBuffers()
        buildRenderPipelineState()
        buildSamplerState()
        
        /// debug
//        setupProgrammaticCaptureScope()
//        triggerProgrammaticCapture()
    }
}

/// MARK - 构建 buffer 和 属性描述
extension TexturesRenderer {
    private func buildComputePipelineState() {
        let library = device.makeDefaultLibrary()
        let addFunction = library?.makeFunction(name: "add_arrays")
        
        do {
            computePipelineState = try device.makeComputePipelineState(function: addFunction!)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
    }
    
    
    private func buildVertexBuffers() {
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: [])
        
        // 参考 cocos2d，预先创建一个大的 buffer
        instancesBuffer = device.makeBuffer(length: 65536 * MemoryLayout<InstanceUniform>.stride, options: [])
        instancesBuffer.label = "Instance Buffer"
    }
    
    private func buildRenderPipelineState() {
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "instance_vertex_shader")
        let fragmentFunction = library?.makeFunction(name: "instance_fragment_shader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
    }
    
    private func buildSamplerState() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        samplerState = device.makeSamplerState(descriptor: descriptor)
    }
    
    /// https://developer.apple.com/documentation/metal/debugging_tools/capturing_gpu_command_data_programmatically
    private func setupProgrammaticCaptureScope() {
        myCaptureScope = MTLCaptureManager.shared().makeCaptureScope(device: device)
        myCaptureScope?.label = "My Capture Scope"
    }
    
    private func triggerProgrammaticCapture() {
        guard let captureScope = myCaptureScope else { return }
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = captureScope
        do {
            try captureManager.startCapture(with:captureDescriptor)
        }
        catch
        {
            fatalError("error when trying to capture: \(error)")
        }
    }
}

/// MARK - 更新数据
extension TexturesRenderer {
    func prepare(textures: [MTLTexture]) {
        self.textures.removeAll()
        self.textures.append(contentsOf: textures)
    }
    
    func add(instance: InstanceUniform) {
        instances.append(instance)
    }
}

/// MARK - 渲染
extension TexturesRenderer: MTKViewDelegate {
    private func updateSize(size: CGSize) {
        viewPortSize.x = UInt32(size.width);
        viewPortSize.y = UInt32(size.height);
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateSize(size: size)
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let computePipelineState = computePipelineState,
              let renderPipelineState = renderPipelineState else { return }
        
//        myCaptureScope?.begin()
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
//        /// 1、计算命令编码器
//        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
//        computeCommandEncoder.setComputePipelineState(computePipelineState)
//
//        let size = 2
//        let input: [Float] = [1.0, 2.0]
//        computeCommandEncoder.setBuffer(device.makeBuffer(bytes: input as [Float], length: MemoryLayout<Float>.stride * size, options: []),
//                          offset: 0, index: 0)
//
//        let input1: [Float] = [3.0, 4.0]
//        computeCommandEncoder.setBuffer(device.makeBuffer(bytes: input1 as [Float], length: MemoryLayout<Float>.stride * size, options: []),
//                          offset: 0, index: 1)
//        let outputBuffer = device.makeBuffer(length: MemoryLayout<Float>.stride * size, options: [])!
//        computeCommandEncoder.setBuffer(outputBuffer, offset: 0, index: 2)
//        let gridSize = MTLSize(width: size, height: 1, depth: 1)
//        var threadGroupSize = computePipelineState.maxTotalThreadsPerThreadgroup
//        if threadGroupSize > size {
//            threadGroupSize = size
//        }
//        let threadsPerThreadgroup = MTLSize(width: threadGroupSize, height: 1, depth: 1)
//        computeCommandEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadsPerThreadgroup)
//        computeCommandEncoder.endEncoding()
        
        /// 2、渲染命令编码器
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        
        /// 构建 MVP
        uniform.modeMatrix = matrix4x4_indentify()
        let projectionMatrix = matrix4x4_ortho(left: -Float(viewPortSize.x) / 2.0, right: Float(viewPortSize.x) / 2.0, bottom: -Float(viewPortSize.y) / 2.0, top: Float(viewPortSize.y) / 2.0, nearZ: -1, farZ: 1)
        uniform.projectionMatrix = projectionMatrix
        
        /// 渲染设置
        renderCommandEncoder.setFrontFacing(.counterClockwise)// 逆时针为正面
        renderCommandEncoder.setCullMode(.back)// 背面剔除
        
        /// 设置渲染管线
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        
        /// 设置采样器
        renderCommandEncoder.setFragmentSamplerState(samplerState, index: 0)
        
        /// 顶点缓冲，只有一份单位正方形顶点数据
        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        /// 设置 MVP
        renderCommandEncoder.setVertexBytes(&uniform, length: MemoryLayout<Uniform>.stride, index: 1)
        
        /// 多重纹理
//        for (index, texture) in textures.enumerated() {
//            renderCommandEncoder.setFragmentTexture(texture, index: index)
//        }
        
        renderCommandEncoder.setFragmentTextures(textures, range: 0..<textures.count)
        
        /// 实例化数据
//        renderCommandEncoder.setVertexBytes(&instances, length: MemoryLayout<InstanceUniform>.stride * instances.count, index: 2)
        
        // 如果定义的 buffer 的长度小于实例数据长度，动态扩容并创建一个新的 MTLBuffer，并把实例数据拷贝到 MTLBuffer里，这是参考 SDL 里的做法
        if instancesBuffer.length < MemoryLayout<InstanceUniform>.stride * instances.count {
            let dataLength = Double(instances.count * MemoryLayout<InstanceUniform>.stride)
            var length = Double(instancesBuffer.length) * 1.4
            while length < dataLength {
                length *= 1.4
            }
            instancesBuffer = device.makeBuffer(length: instances.count * MemoryLayout<InstanceUniform>.stride, options: [])
            instancesBuffer.label = "Instance Buffer"
        }
        
        instancesBuffer.contents().copyMemory(from: &instances, byteCount: MemoryLayout<InstanceUniform>.stride * instances.count)
        renderCommandEncoder.setVertexBuffer(instancesBuffer, offset: 0, index: 2)
        
        /// 实例化渲染
        renderCommandEncoder.drawIndexedPrimitives(type: primitiveType, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0, instanceCount: instances.count)
        renderCommandEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
//        commandBuffer.waitUntilCompleted()
//
//        var pointer = outputBuffer.contents().bindMemory(to: Float.self, capacity: size)
//        let one = pointer.pointee
//        pointer = pointer.advanced(by: 1)
//        let two = pointer.pointee
        
//        myCaptureScope?.end()
    }
}
