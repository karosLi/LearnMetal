//
//  TexturesRenderer.swift
//  MetalEnv
//
//  Created by karos li on 2021/8/27.
//

import MetalKit

var icbCommandMaxCount = 5000
var instanceBufferCount = 65535
var maxGPUBindTextureCount = 32

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
    private var icgComputeFunction: MTLFunction!
    
    /// icb 参数缓冲，包含 indirectCommandBuffer，让 compute shader 可以拿到这个参数，从而拿到里面存储的 icb
    private var icbArgumentBuffer: MTLBuffer!
    /// 间接命令缓冲，渲染命令通过compute shader转发给渲染管线
    private var indirectCommandBuffer: MTLIndirectCommandBuffer?
    /// 渲染管线，需要通过参数缓冲传给计算着色器
    private var renderPipelineState: MTLRenderPipelineState?
    
    /// icb 材质 buffer
    private var icbMaterialArgumentBuffer: MTLBuffer!
    
    /// 片元着色器
    private var fragmentFunction: MTLFunction!
    /// 片元材质参数编码
    private var fragmentMaterialArgumentEncoder: MTLArgumentEncoder!
    
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
        let library = MetalContext.device.makeDefaultLibrary()
        let GPUCommandEncodingKernel = library?.makeFunction(name: "model_matrix_compute")
        self.icgComputeFunction = GPUCommandEncodingKernel
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
        let icbMaterialArgumentEncoder = GPUCommandEncodingKernel!.makeArgumentEncoder(bufferIndex: KernelBufferIndexTextures.index)
        icbMaterialArgumentBuffer = MetalContext.device.makeBuffer(length: icbMaterialArgumentEncoder.encodedLength, options: .storageModeShared)
        icbMaterialArgumentBuffer.label = "Compute Textures Argument Buffer"
        
        /// 把纹理都绑定到片元着色器上
        let fragmentMaterialArgumentEncoder = fragmentFunction.makeArgumentEncoder(bufferIndex: FragmentBufferIndexMaterials.index)
        let fragmentMaterialArgumentBuffer = MetalContext.device.makeBuffer(length: fragmentMaterialArgumentEncoder.encodedLength, options: .storageModeShared)
        fragmentMaterialArgumentBuffer?.label = "Fragment Textures Argument Buffer"
        fragmentMaterialArgumentEncoder.setArgumentBuffer(fragmentMaterialArgumentBuffer, offset: 0)
        self.fragmentMaterialArgumentEncoder = fragmentMaterialArgumentEncoder
        
        /// 把片元着色器的每个参数缓冲，设置到计算着色器上
        icbMaterialArgumentEncoder.setArgumentBuffer(icbMaterialArgumentBuffer, offset: 0)
        icbMaterialArgumentEncoder.setBuffer(fragmentMaterialArgumentBuffer, offset: 0, index: 0)
    }
    
    private func buildVertexBuffers() {
        vertexBuffer = MetalContext.device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])
//        indexBuffer = MetalContext.device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: [])
        
        // 参考 cocos2d，预先创建一个大的 buffer
        instancesBuffer = MetalContext.device.makeBuffer(length: instanceBufferCount * MemoryLayout<InstanceUniform>.stride, options: [])
        instancesBuffer.label = "Instance Buffer"
    }
    
    private func buildRenderPipelineState() {
        let library = MetalContext.device.makeDefaultLibrary()
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
    
    func configDrawableInstance(_ instance: InstanceUniform) {
        let instancePointer = nextInstance()
        instancePointer.pointee.center = instance.center
        instancePointer.pointee.size = instance.size
        instancePointer.pointee.radian = instance.radian
        instancePointer.pointee.textureFrame = instance.textureFrame
        instancePointer.pointee.textureRadian = instance.textureRadian
        instancePointer.pointee.textureId = instance.textureId
        instancePointer.pointee.textureIndex = instance.textureIndex
    }
    
    private func nextInstance() -> UnsafeMutablePointer<InstanceUniform> {
        checkInstanceBufferCount()
        
        var pointer = instancesBuffer.contents().bindMemory(to: InstanceUniform.self, capacity: instanceBufferCount)
        pointer = pointer.advanced(by: drawCount)
        drawCount += 1
        
        return pointer
    }
    
    private func checkInstanceBufferCount() {
        guard let existInstancesBuffer = instancesBuffer else { return }
        
        // 如果定义的 buffer 的长度小于实例数据长度，动态扩容并创建一个新的 MTLBuffer，并把实例数据拷贝到 MTLBuffer里，这是参考 SDL 里的做法
        if instanceBufferCount < drawCount {
            var count = instanceBufferCount
            count = count + count / 2
            while count < drawCount {
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
              let computePipelineState = icbComputePipelineState,
              let indirectCommandBuffer = indirectCommandBuffer else { return }
        
//        myCaptureScope?.begin()
        
        delegate?.update()
        
        let commandBuffer = MetalContext.commandQueue.makeCommandBuffer()!
        commandBuffer.label = "Frame Command Buffer"
        
        let instanceCount = drawCount
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
        
        var fromDrawIndex = 0
        var endDrawIndex = drawCount - 1
        
        var pointer = instancesBuffer.contents().bindMemory(to: InstanceUniform.self, capacity: instanceBufferCount)
        for drawIndex in 0..<drawCount {
            /// 如果实际物体数量大于 icbCommandMaxCount 或者 超过 32 重纹理，就分批 draw call
            var willExceedMaxTextureNum = false
            let textureId = pointer.pointee.textureId
            var textureIndex: Int = 0
            var foundSame = false
            for (saveTextureIndex, saveTextureId) in textureIndexes {
                if textureId == saveTextureId {// 说明待绑定纹理列表中找到了纹理id，那么可以直接把存储的纹理索引赋值给实例
                    textureIndex = saveTextureIndex
                    foundSame = true
                    break
                }
            }

            // 如果没有找到就把纹理id加入到待绑定纹理列表里
            if !foundSame {
                // 判断下是否有超过单次绘制的最大纹理数量
                if textureIndexes.count < maxGPUBindTextureCount {
                    let index = textureIndexes.count
                    textureIndexes[index] = Int(textureId)
                    textureIndex = index
                }

                // 添加完成后判断下是否即将超过最大纹理
                willExceedMaxTextureNum = textureIndexes.count >= maxGPUBindTextureCount
            }

            pointer.pointee.textureIndex = Int32(textureIndex)

            /// 如果即将超过，就先绘制一次
            if willExceedMaxTextureNum {
                endDrawIndex = drawIndex
                draw(renderEncoder, range: fromDrawIndex..<endDrawIndex + 1)
                fromDrawIndex = endDrawIndex + 1
            }

            pointer = pointer.advanced(by: 1)
        }
        
        if fromDrawIndex < endDrawIndex + 1 {
            draw(renderEncoder, range: fromDrawIndex..<endDrawIndex + 1)
        }
        
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
//        myCaptureScope?.end()
    }
    
    private func draw(_ renderEncoder: MTLRenderCommandEncoder, range: Range<Int>) {
        guard let indirectCommandBuffer = indirectCommandBuffer else { return }
        
        /// 使用本地数组去赋值给 shader，不然成员变量在多个 draw call 时会导致数据被修改，从而导致后面的 draw call 绑定的纹理 会影响前面的 draw call 的绑定的纹理
        var textures = [MTLTexture]()
        for index in 0..<textureIndexes.count {
            let saveTextureId = textureIndexes[index]
            if let texture = TextureController.getTexture(saveTextureId) {
                textures.append(texture)
            }
        }
        textureIndexes.removeAll()
        
        /// 动态修改绑定到片元着色上的 argument buffer 中保存的纹理数组
        fragmentMaterialArgumentEncoder.setTextures(textures, range: 0..<textures.count)
        
        // 因为使用的是 argument buffer 里的纹理，所以需要显示使用资源
        renderEncoder.useResources(textures, usage: .read)
        renderEncoder.executeCommandsInBuffer(indirectCommandBuffer, range: range)
    }
}

extension TexturesRenderer {
    private func getTextureIndex() -> Int {
        return 0
    }
}
