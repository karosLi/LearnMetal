//
//  TexturesRenderer.swift
//  MetalEnv
//
//  Created by karos li on 2021/8/27.
//

import MetalKit

var instanceBufferCount = 10000

/// https://developer.apple.com/documentation/metal/
class TexturesRenderer: NSObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var viewPortSize: vector_uint2 = vector_uint2(1,1)
    
    private var icbDescriptor: MTLIndirectCommandBufferDescriptor!
    /// 间接命令缓冲，渲染命令通过compute shader转发给渲染管线
    private var indirectCommandBuffer: MTLIndirectCommandBuffer?
    /// icb 参数缓冲，包含 indirectCommandBuffer，让 compute shader 可以拿到这个参数，从而拿到里面存储的 icb
    private var icbArgumentBuffer: MTLBuffer!
    
    private var computePipelineState: MTLComputePipelineState?
    private var GPUCommandEncodingKernel: MTLFunction!
    
    private var renderPipelineState: MTLRenderPipelineState?
    private var uniformBuffer: MTLBuffer!
    private var vertexBuffer: MTLBuffer!
//    private var indexBuffer: MTLBuffer!
    private var instanceBuffer: MTLBuffer!
    private var fragmentFunction: MTLFunction!
    
    private var computeTextureArgumentBuffer: MTLBuffer!
    
    private var fragmentTextureArgumentBuffers: [MTLBuffer] = []
    private var fragmentTextureArgumentEncoders: [MTLArgumentEncoder] = []

    private var samplerState: MTLSamplerState?
    private var textures = [MTLTexture]()
    private var instances = [InstanceUniform]()
    
    private var uniform = Uniform()
    
    private var myCaptureScope: MTLCaptureScope?
    
    /// 单位正方形顶点数据
    private let vertices: [Vertex] = [
        Vertex(position: vector4(-0.5,  0.5, 0.0, 1.0),
               textureCoords: vector2(0, 1), textureIndex: 0), // V0 左上
        Vertex(position: vector4(-0.5, -0.5, 0.0, 1.0),
               textureCoords: vector2(0, 0), textureIndex: 0), // V1 左下
        Vertex(position: vector4(0.5, -0.5, 0.0, 1.0),
               textureCoords: vector2(1, 0), textureIndex: 0), // V2 右下
        Vertex(position: vector4(0.5, -0.5, 0.0, 1.0),
               textureCoords: vector2(1, 0), textureIndex: 0), // V2 右下
        Vertex(position: vector4(0.5,  0.5, 0.0, 1.0),
               textureCoords: vector2(1, 1), textureIndex: 0),  // V3 右上
        Vertex(position: vector4(-0.5,  0.5, 0.0, 1.0),
               textureCoords: vector2(0, 1), textureIndex: 0), // V0 左上
    ]
    
    /// 单位正方形顶点索引
//    private var indices: [UInt16] {
//        return [
//            0, 1, 2,
//            2, 3, 0
//        ]
//    }
    
    init(device: MTLDevice, size: CGSize) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        super.init()
        buildVertexBuffers()
        buildRenderPipelineState()
        buildSamplerState()
        updateSize(size: size)
        buildICB()
        
        /// debug
//        setupProgrammaticCaptureScope()
//        triggerProgrammaticCapture()
    }
}

/// MARK - 构建 buffer 和 属性描述
extension TexturesRenderer {
    
    private func buildICB() {
        let library = device.makeDefaultLibrary()
        let GPUCommandEncodingKernel = library?.makeFunction(name: "model_matrix_compute")
        self.GPUCommandEncodingKernel = GPUCommandEncodingKernel
        do {
            computePipelineState = try device.makeComputePipelineState(function: GPUCommandEncodingKernel!)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
        
        icbDescriptor = MTLIndirectCommandBufferDescriptor()
        icbDescriptor.commandTypes = .drawIndexed
        // Indicate that buffers will be set for each command in the indirect command buffer.
        icbDescriptor.inheritBuffers = false
        
        // Indicate that a maximum of 4 buffers will be set for each command.
        icbDescriptor.maxVertexBufferBindCount = 8
        icbDescriptor.maxFragmentBufferBindCount = 8
        
        // Indicate that the render pipeline state object will be set in the render command encoder
        // (not by the indirect command buffer).
        // On iOS, this property only exists on iOS 13 and later.  Earlier versions of iOS did not
        // support settings pipelinestate within an indirect command buffer, so indirect command
        // buffers always inherited the pipeline state.
        if #available(iOS 13.0, *) {
//            icbDescriptor.inheritPipelineState = true
        }
        
        // Create indirect command buffer using private storage mode; since only the GPU will
        // write to and read from the indirect command buffer, the CPU never needs to access the
        // memory
        // maxCommandCount 是要渲染的实例数量
        indirectCommandBuffer = device.makeIndirectCommandBuffer(descriptor: icbDescriptor, maxCommandCount: instanceBufferCount, options: .storageModePrivate)
        indirectCommandBuffer?.label = "Scene ICB"

        // compute shader 添加参数
        let icbArgumentEncoder = GPUCommandEncodingKernel!.makeArgumentEncoder(bufferIndex: KernelBufferIndexICBContainer.index)
        icbArgumentBuffer = device.makeBuffer(length: icbArgumentEncoder.encodedLength, options: .storageModeShared)
        icbArgumentBuffer.label = "ICB Argument Buffer"

        icbArgumentEncoder.setArgumentBuffer(icbArgumentBuffer, offset: 0)
        icbArgumentEncoder.setIndirectCommandBuffer(indirectCommandBuffer, index: ArgumentBufferIDCommandBuffer.index)
        /// 当设置了 render pipeline 后，就可以不用 设置 icbDescriptor.inheritPipelineState = true，这样就可以至少从 iOS 12 开始写代码了
        icbArgumentEncoder.setRenderPipelineState(renderPipelineState, index: ArgumentBufferIDPipeline.index)
        
        ///计算 shader绑定参数缓冲
        let computeTexturesArgumentEncoder = GPUCommandEncodingKernel!.makeArgumentEncoder(bufferIndex: KernelBufferIndexTextures.index)
        let textureArgumentSize = computeTexturesArgumentEncoder.encodedLength
        computeTextureArgumentBuffer = device.makeBuffer(length: textureArgumentSize * instanceBufferCount, options: .storageModeShared)
        computeTextureArgumentBuffer.label = "Compute Textures Argument Buffer"
        
        /// 把纹理都绑定到片元着色器上
        fragmentTextureArgumentBuffers.removeAll()
        fragmentTextureArgumentEncoders.removeAll()
        for index in 0..<instanceBufferCount {
            let fragmentTexturesArgumentEncoder = fragmentFunction.makeArgumentEncoder(bufferIndex: FragmentBufferIndexMaterials.index)
            let fragmentTextureArgumentBuffer = device.makeBuffer(length: fragmentTexturesArgumentEncoder.encodedLength, options: .storageModeShared)
            fragmentTextureArgumentBuffer?.label = "Fragment Textures Argument Buffer"
            fragmentTexturesArgumentEncoder.setArgumentBuffer(fragmentTextureArgumentBuffer, offset: 0)
            fragmentTextureArgumentBuffers.append(fragmentTextureArgumentBuffer!)
            fragmentTextureArgumentEncoders.append(fragmentTexturesArgumentEncoder)
            
            /// 把片元着色器的每个参数缓冲，设置到计算着色器上
            computeTexturesArgumentEncoder.setArgumentBuffer(
                computeTextureArgumentBuffer, startOffset: 0, arrayElement: index)
            computeTexturesArgumentEncoder.setBuffer(fragmentTextureArgumentBuffer, offset: 0, index: 0)
        }
    }
    
    private func buildVertexBuffers() {
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])
//        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: [])
    }
    
    private func buildRenderPipelineState() {
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "instance_vertex_shader")
        let fragmentFunction = library?.makeFunction(name: "instance_fragment_shader")
        self.fragmentFunction = fragmentFunction
        
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
        // render pass 需要支持 命令转发
        pipelineDescriptor.supportIndirectCommandBuffers = true
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
        
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniform>.stride, options: [])
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
        if #available(iOS 13.0, *) {
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
    
    func removeAllInstances() {
        instances.removeAll()
    }
    
    func setupInstances() {
        let instance = InstanceUniform(center: vector_float2(0.0, 300.0), size: vector_float2(500.0, 500.0), radian: 0.0, textureIndex: 0, textureFrame: vector_float4(0.0, 0.0, 1.0, 1.0), textureRadian: 0, modelMatrix: matrix4x4_indentify())
        instances.append(instance)
        
        let instance1 = InstanceUniform(center: vector_float2(0.0, -300.0), size: vector_float2(500.0, 500.0), radian: 0.0, textureIndex: 1, textureFrame: vector_float4(0.0, 0.0, 1.0, 1.0), textureRadian: 0, modelMatrix: matrix4x4_indentify())
        instances.append(instance1)
        
        
        for _ in 0..<9998 {
            let instance1 = InstanceUniform(center: vector_float2(0.0, -300.0), size: vector_float2(500.0, 500.0), radian: 0.0, textureIndex: 1, textureFrame: vector_float4(0.0, 0.0, 1.0, 1.0), textureRadian: 0, modelMatrix: matrix4x4_indentify())
            instances.append(instance1)
        }
//
//        for _ in 0..<1000 {
//            let instance1 = InstanceUniform(center: vector_float2(0.0, -300.0), size: vector_float2(500.0, 500.0), radian: 0.0, textureIndex: 1, textureFrame: vector_float4(0.0, 0.0, 1.0, 1.0), textureRadian: 0, modelMatrix: matrix4x4_indentify())
//            instances.append(instance1)
//        }
        
//        instanceBuffer = device.makeBuffer(bytes: &instances, length: MemoryLayout<InstanceUniform>.stride * instances.count, options: [])
        instanceBuffer = device.makeBuffer(bytes: &instances, length: MemoryLayout<InstanceUniform>.stride * instances.count, options: [])
    }
}

/// MARK - 渲染
extension TexturesRenderer: MTKViewDelegate {
    private func updateSize(size: CGSize) {
        viewPortSize.x = UInt32(size.width);
        viewPortSize.y = UInt32(size.height);
        
        /// 构建 MVP
        uniform.modelMatrix = matrix4x4_indentify()
        uniform.viewMatrix = matrix4x4_indentify()
        let projectionMatrix = matrix4x4_ortho(left: -Float(viewPortSize.x) / 2.0, right: Float(viewPortSize.x) / 2.0, bottom: -Float(viewPortSize.y) / 2.0, top: Float(viewPortSize.y) / 2.0, nearZ: -1, farZ: 1)
        uniform.projectionMatrix = projectionMatrix
        uniformBuffer.contents().copyMemory(from: &uniform, byteCount: MemoryLayout<Uniform>.stride)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateSize(size: size)
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let computePipelineState = computePipelineState,
              let indirectCommandBuffer = indirectCommandBuffer else { return }
        
//        myCaptureScope?.begin()
        let instanceCount = instances.count
        let instanceRange = 0..<instanceCount
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        commandBuffer.label = "Frame Command Buffer"
        
        commandBuffer.pushDebugGroup("设置纹理开始")
        /// 如果实际物理数量大于 instanceBufferCount，就分批 draw call
        /// 动态修改绑定到片元着色上的 argument buffer 中保存的纹理
        for (var index, texture) in textures.enumerated() {
            let fragmentTexturesArgumentEncoder = fragmentTextureArgumentEncoders[index]
            fragmentTexturesArgumentEncoder.setTexture(texture, index: 0)
            fragmentTexturesArgumentEncoder.constantData(at: 1).copyMemory(from: &index, byteCount: MemoryLayout<Int>.stride)
        }
        
        
        for var index in 2..<32 {
//            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
//                return
//            }
//            let fragmentTextureArgumentBuffer = fragmentTextureArgumentBuffers[index]
//
//            blitEncoder.copy(from: textures.first!, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: 0, height: 0, depth: 1), to: fragmentTextureArgumentBuffer, destinationOffset: 0, destinationBytesPerRow: 0, destinationBytesPerImage: 0)
//            blitEncoder.endEncoding()
//
//
            
            
            
            let fragmentTexturesArgumentEncoder = fragmentTextureArgumentEncoders[index]
            fragmentTexturesArgumentEncoder.setTexture(textures.first, index: 0)
            fragmentTexturesArgumentEncoder.constantData(at: 1).copyMemory(from: &index, byteCount: MemoryLayout<Int>.stride)

            

        }
        
        
        commandBuffer.pushDebugGroup("设置纹理结束")
        
        /// 重置 indirect command buffer
        let resetBlitEncoder = commandBuffer.makeBlitCommandEncoder()
        resetBlitEncoder?.label = "Reset ICB Blit Encoder"
        resetBlitEncoder?.resetCommandsInBuffer(indirectCommandBuffer, range: instanceRange)
        resetBlitEncoder?.endEncoding()
        
        
        /// 使用 compute kernel 去提前计算矩阵
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        computeEncoder?.label = "Instance Matrix Kernel"
        computeEncoder?.setComputePipelineState(computePipelineState)
        
        // 设置 顶点 缓冲，只有一份单位正方形顶点数据
        computeEncoder?.setBuffer(vertexBuffer, offset: 0, index: KernelBufferIndexVertices.index)
        // 设置 顶点索引缓冲
//        computeEncoder?.setBuffer(indexBuffer, offset: 0, index: KernelBufferIndexIndices.index)
        // 设置 MVP uniform 缓冲
        computeEncoder?.setBuffer(uniformBuffer, offset: 0, index: KernelBufferIndexUniform.index)
        // 设置 实例化数据 缓冲
        computeEncoder?.setBuffer(instanceBuffer, offset: 0, index: KernelBufferIndexInstanceUniforms.index)
        // 设置 icb 参数 缓冲
        computeEncoder?.setBuffer(icbArgumentBuffer, offset: 0, index: KernelBufferIndexICBContainer.index)
        // 设置 纹理 参数 缓冲
        computeEncoder?.setBuffer(computeTextureArgumentBuffer, offset: 0, index: KernelBufferIndexTextures.index)
        
//        computeEncoder?.useResource(computeTextureArgumentBuffer, usage: .read)
        
        // Call useResource on '_indirectCommandBuffer' which indicates to Metal that the kernel will
        // access '_indirectCommandBuffer'.  It is necessary because the app cannot directly set
        // '_indirectCommandBuffer' in 'computeEncoder', but, rather, must pass it to the kernel via
        // an argument buffer which indirectly contains '_indirectCommandBuffer'.
        computeEncoder?.useResource(indirectCommandBuffer, usage: .write)
        
        
        // 获取总线程数，也就是网格数量
        let gridSize = MTLSize(width: instanceCount, height: 1, depth: 1)
        // 获取线程并发数量并确定单个线程组里线程数
        let threadExecutionWidth = computePipelineState.threadExecutionWidth
        let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
        computeEncoder?.dispatchThreads(gridSize, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder?.endEncoding()
        
        /// 优化 indirect command buffer
        let optimizeBlitEncoder = commandBuffer.makeBlitCommandEncoder()
        optimizeBlitEncoder?.label = "Optimize ICB Blit Encoder"
        optimizeBlitEncoder?.optimizeIndirectCommandBuffer(indirectCommandBuffer, range: instanceRange)
        optimizeBlitEncoder?.endEncoding()
        
        
        /// 渲染命令
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        // 设置渲染管线，不需要设置了，因为 ICB 里已经设置了
//        renderEncoder.setRenderPipelineState(renderPipelineState)
        // 多重纹理
//        for (index, texture) in textures.enumerated() {
//            renderEncoder.setFragmentTexture(texture, index: index)
//        }
        
//        /// 实例化渲染
//        // 设置 顶点 缓冲，只有一份单位正方形顶点数据
//        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: KernelBufferIndexVertices.index)
//        // 设置 顶点索引缓冲
//        renderEncoder.setVertexBuffer(indexBuffer, offset: 0, index: KernelBufferIndexIndices.index)
//        // 设置 MVP uniform 缓冲
//        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: KernelBufferIndexUniform.index)
//        // 设置 实例化数据 缓冲
//        renderEncoder.setVertexBuffer(instanceBuffer, offset: 0, index: KernelBufferIndexInstanceUniforms.index)
//
//        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0, instanceCount: instances.count)

        
//        renderEncoder.useResource(vertexBuffer, usage: .read)
////        renderEncoder.useResource(indexBuffer, usage: .read)
//        renderEncoder.useResource(uniformBuffer, usage: .read)
//        renderEncoder.useResource(instanceBuffer, usage: .read)
        
        // 因为使用的是 argument buffer 里的纹理，所以需要显示使用资源
        renderEncoder.useResources(textures, usage: .read)
//        renderEncoder.setFragmentBuffer(textureArgumentBuffer, offset: 0, index: KernelBufferIndexTextures.index)
        renderEncoder.executeCommandsInBuffer(indirectCommandBuffer, range: instanceRange)
        renderEncoder.endEncoding()
        
        // 控制每帧显示间隔时间
        // Present drawable to screen only after previous drawable has been on screen for a
        // mimimum of 16ms to achieve a smooth framerate of 60 FPS.  This prevents jittering on
        // devices with ProMotion displays that support a variable refresh rate from 120 to 30 FPS.
//        commandBuffer.present(drawable, afterMinimumDuration: 0.016)
        commandBuffer.present(drawable)
        commandBuffer.commit()
//        myCaptureScope?.end()
    }
}
