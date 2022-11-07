//
//  TexturesRenderer.swift
//  MetalEnv
//
//  Created by karos li on 2021/8/27.
//

import MetalKit

/// 根据游戏场景定义一个最大 icb 命令次数
var icbMaxCommandCount = 10000
/// 根据游戏场景定义一个最大的纹理数
var icbMaxMaterialCount = 1000
/// 实例 buffer 数量，因为不能分批，所以需要和 icbMaxCommandCount 保持一致
var instanceBufferCount = 10000

protocol TexturesRendererProtocol: NSObject {
    func update()
}

/// https://developer.apple.com/documentation/metal/
class TexturesRenderer: NSObject {
    public weak var delegate: TexturesRendererProtocol?
    
    private lazy var inFlightSemaphore = DispatchSemaphore(value: 3)
    
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
    private var depthStencilState: MTLDepthStencilState?
    
    /// icb 材质 buffer
    public var icbMaterialArgumentBuffer: MTLBuffer!
    public var icbMaterialArgumentEncoder: MTLArgumentEncoder!
    
    private var fragmentFunction: MTLFunction!
    private var fragmentMaterialArgumentEncoders: [MTLArgumentEncoder] = []
    private var fragmentMaterialArgumentBuffers: [MTLBuffer] = []
    
    private var uniformBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!
    public var instancesBuffer: MTLBuffer!

    private var samplerState: MTLSamplerState?
    /// 实例纹理索引 - 纹理id
    private var textureIndexes = [Int: Int]()
    
    private var uniform = Uniform()
    
    /// 总共可渲染的实例数量
    private var drawCount = 0
    
    private var myCaptureScope: MTLCaptureScope?
    
    /// 定义场景
    private var scene: SceneContainer
    
    /// 单位正方形顶点索引，这里建议使用 UInt32，UInt16 不知道为什么 Metal 识别不了
    private var indices: [UInt32] {
        return [
            0, 1, 2,
            1, 3, 2
        ]
    }
    
    init(size: CGSize, scene: Scene) {
        self.scene = scene
        super.init()
        
        buildVertexBuffers()
        buildRenderPipelineState()
        buildSamplerState()
        updateSize(size: size)
        buildSamplerState()
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
        icbDescriptor.maxVertexBufferBindCount = 10
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
        indirectCommandBuffer = MetalContext.device.makeIndirectCommandBuffer(descriptor: icbDescriptor, maxCommandCount: icbMaxCommandCount, options: .storageModePrivate)
        indirectCommandBuffer?.label = "Scene ICB"

        // compute shader 添加参数
        let icbArgumentEncoder = GPUCommandEncodingKernel!.makeArgumentEncoder(bufferIndex: KernelBufferIndexICBContainer.index)
        icbArgumentBuffer = MetalContext.device.makeBuffer(length: icbArgumentEncoder.encodedLength, options: .storageModeShared)
        icbArgumentBuffer.label = "ICB Argument Buffer"

        icbArgumentEncoder.setArgumentBuffer(icbArgumentBuffer, offset: 0)
        icbArgumentEncoder.setIndirectCommandBuffer(indirectCommandBuffer, index: ArgumentBufferIDCommandBuffer.index)
        /// 当设置了 render pipeline 后，就可以不用 设置 icbDescriptor.inheritPipelineState = true，这样就可以至少从 iOS 12 开始写代码了
        icbArgumentEncoder.setRenderPipelineState(renderPipelineState, index: ArgumentBufferIDPipeline.index)
//        icbArgumentEncoder.setSamplerState(samplerState, index: ArgumentBufferIDSampler.index)
        
        ///计算 shader绑定参数缓冲
        let icbMaterialArgumentEncoder = icbComputeFunction.makeArgumentEncoder(bufferIndex: KernelBufferIndexTextures.index)
        icbMaterialArgumentBuffer = MetalContext.device.makeBuffer(length: icbMaterialArgumentEncoder.encodedLength * icbMaxCommandCount, options: .storageModeShared)
        icbMaterialArgumentBuffer.label = "Compute Textures Argument Buffer"
        self.icbMaterialArgumentEncoder = icbMaterialArgumentEncoder
        
        for index in 0..<icbMaxMaterialCount {
            let fragmentMaterialArgumentEncoder = fragmentFunction.makeArgumentEncoder(bufferIndex: FragmentBufferIndexMaterial.index)
            let fragmentMaterialArgumentBuffer = MetalContext.device.makeBuffer(length: fragmentMaterialArgumentEncoder.encodedLength, options: .storageModeShared)!
            fragmentMaterialArgumentBuffer.label = "Fragment Material Argument Buffer"
            fragmentMaterialArgumentEncoder.setArgumentBuffer(fragmentMaterialArgumentBuffer, offset: 0)
            fragmentMaterialArgumentEncoders.append(fragmentMaterialArgumentEncoder)
            fragmentMaterialArgumentBuffers.append(fragmentMaterialArgumentBuffer)
            
            /// 把片元着色器的每个参数缓冲，设置到计算着色器上
            icbMaterialArgumentEncoder.setArgumentBuffer(
                icbMaterialArgumentBuffer, startOffset: 0, arrayElement: index)
            icbMaterialArgumentEncoder.setBuffer(fragmentMaterialArgumentBuffer, offset: 0, index: 0)
        }
    }
    
    private func buildVertexBuffers() {
        indexBuffer = MetalContext.device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride, options: [])
        indexBuffer.label = "Index Buffer"
        
        // 参考 cocos2d，预先创建一个大的 buffer
        instancesBuffer = MetalContext.device.makeBuffer(length: instanceBufferCount * MemoryLayout<InstanceUniform>.stride, options: [])
        instancesBuffer.label = "Instance Buffer"
    }
    
    private func buildRenderPipelineState() {
        let vertexFunction = MetalContext.library.makeFunction(name: "instance_vertex_shader")
        let fragmentFunction = MetalContext.library.makeFunction(name: "instance_fragment_shader")
        self.fragmentFunction = fragmentFunction
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        /// 多个物体重叠在一个位置时，颜色混合非常耗性能
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true;
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha;
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha;
        
        
//        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add;
//        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add;
//        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha;
//        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha;
//        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha;
//        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha;

        
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
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = MetalContext.device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        
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
    
    private func checkInstanceBufferCount(_ instanceUniformsCount: Int) {
        guard let existInstancesBuffer = instancesBuffer else { return }
        
        // 如果定义的 buffer 的长度小于实例数据长度，动态扩容并创建一个新的 MTLBuffer，并把实例数据拷贝到 MTLBuffer里，这是参考 SDL 里的做法
        let instanceCount = instanceUniformsCount
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
        uniform.viewMatrix = .identity
        let projectionMatrix = Float4x4.init(orthoLeft: -Float(viewPortSize.x) / 2.0, right: Float(viewPortSize.x) / 2.0, bottom: -Float(viewPortSize.y) / 2.0, top: Float(viewPortSize.y) / 2.0, near: 0, far: 1000)
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
        
//        inFlightSemaphore.wait()
        delegate?.update()
        
        let commandBuffer = MetalContext.commandQueue.makeCommandBuffer()!
        commandBuffer.label = "Frame Command Buffer"
//        commandBuffer.addCompletedHandler { [weak self] (_) in
//            self?.inFlightSemaphore.signal()
//        }
        
        var instanceUniforms: [InstanceUniform] = []
        var materials: [Material] = []
        for renderContainer in scene.renderContainers {
            for renderable in renderContainer.renderables {
                if !renderable.isHidden {
                    if let index = materials.firstIndex(of: renderable.material) {
                        renderable.uniform.materialIndex = Int32(index)
                    } else {
                        renderable.uniform.materialIndex = Int32(materials.count)
                        materials.append(renderable.material)
                    }
                    
                    instanceUniforms.append(renderable.uniform)
                }
            }
        }
        
        checkInstanceBufferCount(instanceUniforms.count)
        instancesBuffer.contents().copyMemory(from: instanceUniforms, byteCount: MemoryLayout<InstanceUniform>.stride * instanceUniforms.count)
        
        let instanceCount = instanceUniforms.count
        if instanceCount == 0 {
            return
        }
        
        let instanceRange = 0..<instanceCount
        let icbCommandRange = 0..<icbMaxCommandCount
        
        /// 重置 indirect command buffer
        let resetBlitEncoder = commandBuffer.makeBlitCommandEncoder()
        resetBlitEncoder?.label = "Reset ICB Blit Encoder"
        resetBlitEncoder?.resetCommandsInBuffer(indirectCommandBuffer, range: icbCommandRange)
        resetBlitEncoder?.endEncoding()
        
        /// 使用 compute kernel 去提前计算矩阵
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        computeEncoder?.label = "Instance Matrix Kernel"
        computeEncoder?.setComputePipelineState(computePipelineState)
        
        // 设置 顶点索引缓冲
        computeEncoder?.setBuffer(indexBuffer, offset: 0, index: KernelBufferIndexIndices.index)
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
        computeEncoder?.useResource(indexBuffer, usage: .read)
        computeEncoder?.useResource(uniformBuffer, usage: .read)
        computeEncoder?.useResource(instancesBuffer, usage: .read)
        // 使用堆更快捷
        if let heap = TextureController.heap {
            computeEncoder?.useHeap(heap)
        }
        
        for (index, var material) in materials.enumerated() {
            let fragmentMaterialArgumentBuffer = fragmentMaterialArgumentBuffers[index]
            let fragmentMaterialArgumentEncoder = fragmentMaterialArgumentEncoders[index]
            fragmentMaterialArgumentEncoder.setTexture(material.texture, index: 0)
            fragmentMaterialArgumentEncoder.constantData(at: 1).copyMemory(from: &material.color, byteCount: MemoryLayout<Float3>.stride)
            computeEncoder?.useResource(fragmentMaterialArgumentBuffer, usage: .read)
        }
        
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
        optimizeBlitEncoder?.optimizeIndirectCommandBuffer(indirectCommandBuffer, range: icbCommandRange)
        optimizeBlitEncoder?.endEncoding()
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setCullMode(.back)
//            renderEncoder.setTriangleFillMode(.lines)
        renderEncoder.executeCommandsInBuffer(indirectCommandBuffer, range: instanceRange)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
//        commandBuffer.waitUntilCompleted()
//        myCaptureScope?.end()
    }
}

extension TexturesRenderer {
    private func getRenderables(_ rootNode: Node) -> [Renderable] {
        var renderables: [Renderable] = []
        recursionGetRenderable(rootNode, renderables: &renderables)
        return renderables
    }
    
    private func recursionGetRenderable(_ rootNode: Node, renderables: inout [Renderable]) {
        if let renderable = rootNode as? Renderable {
            renderables.append(renderable)
        }
        
        for childNode in rootNode.children {
            recursionGetRenderable(childNode, renderables: &renderables)
        }
    }
}
