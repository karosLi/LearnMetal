//
//  TexturesRenderer.swift
//  MetalEnv
//
//  Created by karos li on 2021/8/27.
//

import MetalKit

var icbCommandMaxCount = 5000
var instanceBufferCount = 65535

protocol TexturesRendererProtocol: NSObject {
    func update()
}

/// https://developer.apple.com/documentation/metal/
class TexturesRenderer: NSObject {
    public weak var delegate: TexturesRendererProtocol?
    
    private var viewPortSize: vector_uint2 = vector_uint2(1,1)
    
    private var icbDescriptor: MTLIndirectCommandBufferDescriptor!
    /// icb 计算管线
    private var icbComputePipelineState: MTLComputePipelineState?
    /// icb 计算着色器
    private var icbComputeFunction: MTLFunction!
    
    /// icb 参数缓冲，包含 indirectCommandBuffer，让 compute shader 可以拿到这个参数，从而拿到里面存储的 icb
    private var icbArgumentBuffer: MTLBuffer!
    /// 间接命令缓冲，渲染命令通过compute shader转发给渲染管线
    private var indirectCommandBuffer: MTLIndirectCommandBuffer?
    /// 渲染管线，需要通过参数缓冲传给计算着色器
    private var renderPipelineState: MTLRenderPipelineState?
    
    /// icb 材质 buffer
    private var icbMaterialArgumentBuffer: MTLBuffer!
    private var icbMaterialArgumentEncoder: MTLArgumentEncoder!
    
    private var uniformBuffer: MTLBuffer!
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!
    private var instancesBuffer: MTLBuffer!

    private var samplerState: MTLSamplerState?
    /// 实例纹理索引 - 纹理id
    private var textureIndexes = [Int: Int]()
    
    private var uniform = Uniform()
    
    /// 总共可渲染的实例数量
    private var drawCount = 0
    
    private var myCaptureScope: MTLCaptureScope?
    
    /// 单位正方形顶点数据
    private let vertices: [Vertex] = [
        Vertex(position: [-0.5, 0.5, 0.0],
               uv: [0, 1], color: [1, 0, 1]), // V0 左上
        Vertex(position: [-0.5, -0.5, 0.0],
               uv: [0, 0], color: [1, 0, 1]), // V1 左下
        Vertex(position: [0.5, -0.5, 0.0],
               uv: [1, 0], color: [1, 0, 1]), // V2 右下
        Vertex(position: [0.5, -0.5, 0.0],
               uv: [1, 0], color: [1, 0, 1]), // V2 右下
        Vertex(position: [0.5, 0.5, 0.0],
               uv: [1, 1], color: [1, 0, 1]), // V3 右上
        Vertex(position: [-0.5, 0.5, 0.0],
               uv: [0, 1], color: [1, 0, 1]), // V0 左上
    ]
    
    var spriteNodes: [SpriteNode] = []
    
    /// 单位正方形顶点数据
//    private let vertices: [Vertex] = [
//        Vertex(position: vector4(-0.5,  0.5, 0.0, 1.0),
//               textureCoords: vector2(0, 1), textureIndex: 0), // V0 左上
//        Vertex(position: vector4(-0.5, -0.5, 0.0, 1.0),
//               textureCoords: vector2(0, 0), textureIndex: 0), // V1 左下
//        Vertex(position: vector4(0.5, -0.5, 0.0, 1.0),
//               textureCoords: vector2(1, 0), textureIndex: 0), // V2 右下
//        Vertex(position: vector4(0.5,  0.5, 0.0, 1.0),
//               textureCoords: vector2(1, 1), textureIndex: 0),  // V3 右上
//    ]
    
    /// 单位正方形顶点索引
//    private var indices: [UInt16] {
//        return [
//            0, 2, 1,
//            0, 3, 2
//        ]
//    }
    
    init(size: CGSize) {
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
        let GPUCommandEncodingKernel = MetalContext.library.makeFunction(name: "model_matrix_compute")
        self.icbComputeFunction = GPUCommandEncodingKernel
        do {
            icbComputePipelineState = try MetalContext.device.makeComputePipelineState(function: GPUCommandEncodingKernel!)
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
        indirectCommandBuffer = MetalContext.device.makeIndirectCommandBuffer(descriptor: icbDescriptor, maxCommandCount: icbCommandMaxCount, options: .storageModePrivate)
        indirectCommandBuffer?.label = "Scene ICB"

        // compute shader 添加参数
        let icbArgumentEncoder = GPUCommandEncodingKernel!.makeArgumentEncoder(bufferIndex: KernelBufferIndexICBContainer.index)
        icbArgumentBuffer = MetalContext.device.makeBuffer(length: icbArgumentEncoder.encodedLength, options: .storageModeShared)
        icbArgumentBuffer.label = "ICB Argument Buffer"

        icbArgumentEncoder.setArgumentBuffer(icbArgumentBuffer, offset: 0)
        icbArgumentEncoder.setIndirectCommandBuffer(indirectCommandBuffer, index: ArgumentBufferIDCommandBuffer.index)
        /// 当设置了 render pipeline 后，就可以不用 设置 icbDescriptor.inheritPipelineState = true，这样就可以至少从 iOS 12 开始写代码了
        icbArgumentEncoder.setRenderPipelineState(renderPipelineState, index: ArgumentBufferIDPipeline.index)
        
        ///计算 shader绑定参数缓冲
        let icbMaterialArgumentEncoder = icbComputeFunction.makeArgumentEncoder(bufferIndex: KernelBufferIndexTextures.index)
        icbMaterialArgumentBuffer = MetalContext.device.makeBuffer(length: icbMaterialArgumentEncoder.encodedLength * icbCommandMaxCount, options: .storageModeShared)
        icbMaterialArgumentBuffer.label = "Compute Textures Argument Buffer"
        self.icbMaterialArgumentEncoder = icbMaterialArgumentEncoder
    }
    
    private func buildVertexBuffers() {
        vertexBuffer = MetalContext.device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])
//        indexBuffer = MetalContext.device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: [])
        
        // 参考 cocos2d，预先创建一个大的 buffer
        instancesBuffer = MetalContext.device.makeBuffer(length: instanceBufferCount * MemoryLayout<InstanceUniform>.stride, options: [])
        instancesBuffer.label = "Instance Buffer"
    }
    
    private func buildRenderPipelineState() {
        let vertexFunction = MetalContext.library.makeFunction(name: "instance_vertex_shader")
        let fragmentFunction = MetalContext.library.makeFunction(name: "instance_fragment_shader")
        
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
            renderPipelineState = try MetalContext.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
        
        uniformBuffer = MetalContext.device.makeBuffer(length: MemoryLayout<Uniform>.stride, options: [])
    }
    
    private func buildSamplerState() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        samplerState = MetalContext.device.makeSamplerState(descriptor: descriptor)
    }
    
    /// https://developer.apple.com/documentation/metal/debugging_tools/capturing_gpu_command_data_programmatically
    private func setupProgrammaticCaptureScope() {
        myCaptureScope = MTLCaptureManager.shared().makeCaptureScope(device: MetalContext.device)
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
    func reset() {
        drawCount = 0
    }
    
    private func checkInstanceBufferCount() {
        guard let existInstancesBuffer = instancesBuffer else { return }
        
        // 如果定义的 buffer 的长度小于实例数据长度，动态扩容并创建一个新的 MTLBuffer，并把实例数据拷贝到 MTLBuffer里，这是参考 SDL 里的做法
        let instanceCount = spriteNodes.count
        if instanceBufferCount < instanceCount {
            var count = instanceBufferCount
            count = count + count / 2
            while count < instanceCount {
                count = count + count / 2
            }
            
            instanceBufferCount = count
            instancesBuffer = MetalContext.device.makeBuffer(length: count * MemoryLayout<InstanceUniform>.stride, options: [])
            instancesBuffer.label = "Instances Buffer"
            /// 把 就的数据拷贝到新的 buffer 上
            instancesBuffer.contents().copyMemory(from: existInstancesBuffer.contents(), byteCount: existInstancesBuffer.length)
        }
    }
}

/// MARK - 渲染
extension TexturesRenderer: MTKViewDelegate {
    private func updateSize(size: CGSize) {
        viewPortSize.x = UInt32(size.width);
        viewPortSize.y = UInt32(size.height);
        
        /// 构建 MVP
        uniform.modelMatrix = .identity
        uniform.viewMatrix = .identity
        let projectionMatrix = Float4x4.init(orthoLeft: -Float(viewPortSize.x) / 2.0, right: Float(viewPortSize.x) / 2.0, bottom: -Float(viewPortSize.y) / 2.0, top: Float(viewPortSize.y) / 2.0, near: -1, far: 1)
        uniform.projectionMatrix = projectionMatrix
        uniformBuffer.contents().copyMemory(from: &uniform, byteCount: MemoryLayout<Uniform>.stride)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateSize(size: size)
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let computePipelineState = icbComputePipelineState,
              let indirectCommandBuffer = indirectCommandBuffer else { return }
        
//        myCaptureScope?.begin()
        
        delegate?.update()
        
        var textures: [MTLTexture] = []
        /// 把片元着色器的每个参数缓冲，设置到计算着色器上
        for (index, spriteNode) in spriteNodes.enumerated() {
            icbMaterialArgumentEncoder.setArgumentBuffer(icbMaterialArgumentBuffer, startOffset: 0, arrayElement: index)
            icbMaterialArgumentEncoder.setBuffer(spriteNode.materialBuffer, offset: 0, index: 0)
            if let texture = spriteNode.texture {
                textures.append(texture)
            }
        }
        let instanceUniforms: [InstanceUniform] = spriteNodes.map { $0.uniform }
        checkInstanceBufferCount()
        instancesBuffer.contents().copyMemory(from: instanceUniforms, byteCount: MemoryLayout<InstanceUniform>.stride * instanceUniforms.count)
        
        let commandBuffer = MetalContext.commandQueue.makeCommandBuffer()!
        commandBuffer.label = "Frame Command Buffer"
        
        let instanceCount = spriteNodes.count
        let instanceRange = 0..<instanceCount
        
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
        computeEncoder?.setBuffer(instancesBuffer, offset: 0, index: KernelBufferIndexInstanceUniforms.index)
        // 设置 icb 参数 缓冲
        computeEncoder?.setBuffer(icbArgumentBuffer, offset: 0, index: KernelBufferIndexICBContainer.index)
        // 设置 纹理 参数 缓冲
        computeEncoder?.setBuffer(icbMaterialArgumentBuffer, offset: 0, index: KernelBufferIndexTextures.index)
        
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
        // 因为使用的是 argument buffer 里的纹理，所以需要显示使用资源
        renderEncoder.useResources(textures, usage: .read)
        renderEncoder.executeCommandsInBuffer(indirectCommandBuffer, range: instanceRange)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
//        myCaptureScope?.end()
    }
}

extension TexturesRenderer {
    private func getTextureIndex() -> Int {
        return 0
    }
}
